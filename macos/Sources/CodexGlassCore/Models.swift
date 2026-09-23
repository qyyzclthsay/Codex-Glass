import Foundation

public struct QuotaWindow: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var group: String
    public var scope: String?
    public var model: String?
    public var minutes: Double?
    public var remaining: Double
    public var resetsAt: Date?
    public var groupBlocked: Bool
    public init(id: String, group: String = "codex", scope: String? = nil, model: String? = nil,
                minutes: Double? = nil, remaining: Double, resetsAt: Date? = nil, groupBlocked: Bool = false) {
        self.id = id; self.group = group; self.scope = scope; self.model = model
        self.minutes = minutes; self.remaining = remaining; self.resetsAt = resetsAt; self.groupBlocked = groupBlocked
    }
}

public struct ResetCredits: Codable, Sendable, Equatable {
    public var count: Int?
    public var expiresAt: Date?
    public init(count: Int? = nil, expiresAt: Date? = nil) { self.count = count; self.expiresAt = expiresAt }
}

public struct UsageSnapshot: Codable, Sendable, Equatable {
    public var identity: String?
    public var plan: String?
    public var windows: [QuotaWindow]
    public var resets: ResetCredits
    public var observedAt: Date
    public init(identity: String? = nil, plan: String? = nil, windows: [QuotaWindow] = [],
                resets: ResetCredits = ResetCredits(), observedAt: Date = Date()) {
        self.identity = identity; self.plan = plan; self.windows = windows
        self.resets = resets; self.observedAt = observedAt
    }
}

public struct DailyRecord: Codable, Identifiable, Sendable, Equatable {
    public var date: String
    public var tokens: Double?
    public var id: String { date }
    public init(date: String, tokens: Double?) { self.date = date; self.tokens = tokens }
}

public struct DailyUsage: Codable, Sendable, Equatable {
    public var days: [DailyRecord]
    public var observedAt: Date
    public var incomplete: Bool
    public init(days: [DailyRecord], observedAt: Date = Date(), incomplete: Bool = false) {
        self.days = days; self.observedAt = observedAt; self.incomplete = incomplete
    }
}

public struct MembershipDate: Codable, Sendable, Equatable {
    public var date: String
    public var kind: String
    public init(date: String, kind: String = "renewal") { self.date = date; self.kind = kind }
}

public struct AppSettings: Codable, Sendable, Equatable {
    public var language: String = AppSettings.defaultLanguage
    public var theme: String = "system"
    public var accentColor: String?
    public var pinned = true
    public var compact = false
    public var ringWindow = "auto"
    public var elapsedArc = false
    public var startup = false
    public var notifications = false
    public var refreshSeconds = 120
    public var membership: [String: MembershipDate] = [:]
    public var mainWidth: Double = 360
    public var mainHeight: Double = 550

    public init() {}

    public static var defaultLanguage: String {
        let language = Locale.preferredLanguages.first ?? "en"
        if language.hasPrefix("zh-Hant") || language.hasPrefix("zh-TW") || language.hasPrefix("zh-HK") { return "zh-TW" }
        return language.hasPrefix("zh") ? "zh" : "en"
    }

    enum CodingKeys: String, CodingKey {
        case language, theme, accentColor, pinned, compact, ringWindow, elapsedArc, startup, notifications
        case refreshSeconds, membership, mainWidth, mainHeight
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = (try? c.decode(String.self, forKey: .language)) ?? language
        theme = (try? c.decode(String.self, forKey: .theme)) ?? theme
        accentColor = try? c.decode(String.self, forKey: .accentColor)
        pinned = (try? c.decode(Bool.self, forKey: .pinned)) ?? pinned
        compact = (try? c.decode(Bool.self, forKey: .compact)) ?? compact
        ringWindow = (try? c.decode(String.self, forKey: .ringWindow)) ?? ringWindow
        elapsedArc = (try? c.decode(Bool.self, forKey: .elapsedArc)) ?? elapsedArc
        startup = (try? c.decode(Bool.self, forKey: .startup)) ?? startup
        notifications = (try? c.decode(Bool.self, forKey: .notifications)) ?? notifications
        refreshSeconds = (try? c.decode(Int.self, forKey: .refreshSeconds)) ?? refreshSeconds
        membership = (try? c.decode([String: MembershipDate].self, forKey: .membership)) ?? membership
        mainWidth = (try? c.decode(Double.self, forKey: .mainWidth)) ?? mainWidth
        mainHeight = (try? c.decode(Double.self, forKey: .mainHeight)) ?? mainHeight
        self = validated()
    }

    public func validated() -> AppSettings {
        var s = self
        if !["en", "zh", "zh-TW"].contains(s.language) { s.language = Self.defaultLanguage }
        if !["system", "light", "dark"].contains(s.theme) { s.theme = "system" }
        if !["auto", "five", "week"].contains(s.ringWindow) { s.ringWindow = "auto" }
        if ![60, 120, 300, 600].contains(s.refreshSeconds) { s.refreshSeconds = 120 }
        if let color = s.accentColor {
            s.accentColor = color.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil ? color.lowercased() : nil
        }
        s.mainWidth = s.mainWidth.isFinite ? min(900, max(320, s.mainWidth)) : 360
        s.mainHeight = s.mainHeight.isFinite ? min(1400, max(360, s.mainHeight)) : 550
        s.membership = s.membership.filter { key, value in
            key.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil &&
                UsageMath.isValidDate(value.date) && ["renewal", "expiry"].contains(value.kind)
        }
        return s
    }
}

public enum UsageMath {
    public static func selected(snapshot: UsageSnapshot?, choice: String, now: Date = Date()) -> QuotaWindow? {
        let windows = (snapshot?.windows ?? []).filter {
            $0.group == "codex" && $0.remaining.isFinite && ($0.resetsAt.map { $0 > now } ?? true)
        }
        let minutes: Double? = choice == "week" ? 10080 : choice == "five" ? 300 : nil
        if let minutes, let requested = windows.first(where: { $0.minutes == minutes }) { return requested }
        return windows.min { $0.remaining < $1.remaining }
    }

    public static func elapsed(window: QuotaWindow?, now: Date = Date()) -> Double? {
        guard let window, let minutes = window.minutes, minutes.isFinite, minutes > 0, let end = window.resetsAt else { return nil }
        return min(1, max(0, 1 - end.timeIntervalSince(now) / (minutes * 60)))
    }

    public static func series(usage: DailyUsage?, range: Int, today: Date = Date()) -> [DailyRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        var records: [String: Double] = [:]
        for item in usage?.days ?? [] { if let value = item.tokens { records[item.date] = value } }
        return (0..<min(366, max(0, range))).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            let date = dateString(day)
            return DailyRecord(date: date, tokens: records[date])
        }
    }

    public static func tokens(_ value: Double?, language: String, total: Bool = false) -> String {
        guard let value, value.isFinite, value >= 0 else { return "—" }
        let chinese = language == "zh" || language == "zh-TW"
        let scale: Double
        let unit: String
        if chinese {
            scale = total ? 100_000_000 : 10_000
            unit = total ? (language == "zh-TW" ? "億" : "亿") : (language == "zh-TW" ? "萬" : "万")
        } else {
            scale = value >= 1_000_000_000 ? 1_000_000_000 : value >= 1_000_000 ? 1_000_000 : value >= 1_000 ? 1_000 : 1
            unit = scale == 1_000_000_000 ? "B" : scale == 1_000_000 ? "M" : scale == 1_000 ? "K" : ""
        }
        let number: String
        if value == 0 { number = "0" }
        else if chinese && value / scale < 0.01 { number = "<0.01" }
        else {
            let f = NumberFormatter()
            f.locale = Locale(identifier: language == "zh" ? "zh_CN" : language == "zh-TW" ? "zh_TW" : "en_US")
            f.numberStyle = .decimal; f.usesGroupingSeparator = scale == 1
            f.minimumFractionDigits = scale == 1 ? 0 : 2; f.maximumFractionDigits = f.minimumFractionDigits
            number = f.string(from: NSNumber(value: value / scale)) ?? "—"
        }
        return number + (unit.isEmpty ? "" : " " + unit)
    }

    public static func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    public static func isValidDate(_ value: String) -> Bool {
        guard value.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil else { return false }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard let date = f.date(from: value) else { return false }
        return f.string(from: date) == value
    }

    /// A persisted quota is displayed only after the current account has been verified.
    public static func cached(_ snapshot: UsageSnapshot?, identity: String?, now: Date = Date()) -> UsageSnapshot? {
        guard var snapshot, let identity, snapshot.identity == identity,
              now.timeIntervalSince(snapshot.observedAt) <= 86400,
              snapshot.observedAt.timeIntervalSince(now) <= 60 else { return nil }
        snapshot.windows = snapshot.windows.filter { $0.remaining.isFinite && ($0.resetsAt.map { $0 > now } ?? true) }
        guard !snapshot.windows.isEmpty else { return nil }
        snapshot.resets = ResetCredits()
        return snapshot
    }
}
