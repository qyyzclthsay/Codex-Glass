import Foundation
import CryptoKit

enum GlassError: String, Error {
    case signInRequired, accountChanged, codexMissing, timeout, connectionLost, startFailed, invalidReply
    case rateLimited, loginFailed, serverError
}

indirect enum JSONValue: Codable, Sendable, Equatable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(Double.self), value.isFinite { self = .number(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? c.decode([JSONValue].self) { self = .array(value) }
        else { throw GlassError.invalidReply }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let value): try c.encode(value)
        case .array(let value): try c.encode(value)
        case .string(let value): try c.encode(value)
        case .number(let value): try c.encode(value)
        case .bool(let value): try c.encode(value)
        case .null: try c.encodeNil()
        }
    }
    subscript(key: String) -> JSONValue { object?[key] ?? .null }
    var object: [String: JSONValue]? { if case .object(let value) = self { return value }; return nil }
    var array: [JSONValue]? { if case .array(let value) = self { return value }; return nil }
    var string: String? { if case .string(let value) = self { return value }; return nil }
    var number: Double? { if case .number(let value) = self, value.isFinite { return value }; return nil }
    var bool: Bool? { if case .bool(let value) = self { return value }; return nil }
}

enum UsageNormalizer {
    static func identity(_ account: JSONValue, limits: JSONValue = .null) -> String? {
        let candidates = [limits["accountId"], account["accountId"], account["id"], account["email"]]
        guard let raw = candidates.compactMap(\.string).first(where: { !$0.isEmpty }) else { return nil }
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func snapshot(account: JSONValue, result: JSONValue, now: Date = Date()) throws -> UsageSnapshot {
        guard result.object != nil else { throw GlassError.invalidReply }
        let groups: [String: JSONValue]
        if result["rateLimitsByLimitId"] != .null {
            guard let value = result["rateLimitsByLimitId"].object else { throw GlassError.invalidReply }
            groups = value
        } else { groups = ["codex": result["rateLimits"]] }
        var windows: [QuotaWindow] = []
        var plan = account["planType"].string
        for key in groups.keys.sorted(by: { ($0 == "codex" ? "" : $0) < ($1 == "codex" ? "" : $1) }) {
            guard let group = groups[key] else { continue }
            plan = plan ?? group["planType"].string
            for slot in ["primary", "secondary"] {
                let value = group[slot]
                guard let used = value["usedPercent"].number else { continue }
                let reset = timestamp(value["resetsAt"])
                windows.append(QuotaWindow(id: key + ":" + slot, group: key,
                                           scope: group["limitName"].string ?? (key == "codex" ? nil : key),
                                           model: group["normalModelSlug"].string,
                                           minutes: value["windowDurationMins"].number,
                                           remaining: min(100, max(0, 100 - used)), resetsAt: reset,
                                           groupBlocked: group["spendControlReached"].bool == true || group["rateLimitReachedType"] != .null))
            }
        }
        let credits = result["rateLimitResetCredits"]
        let rawCount = credits["availableCount"].number
        let count = rawCount.flatMap { value -> Int? in
            guard value < Double(Int.max) else { return nil }
            return Int(max(0, value.rounded(.down)))
        }
        let expiry = (credits["credits"].array ?? []).filter { $0["status"].string == "available" }
            .compactMap { timestamp($0["expiresAt"]) }.filter { $0 > now }.min()
        return UsageSnapshot(identity: identity(account, limits: result), plan: plan, windows: windows,
                             resets: ResetCredits(count: count, expiresAt: expiry), observedAt: now)
    }

    static func daily(_ raw: JSONValue, now: Date = Date()) throws -> DailyUsage {
        guard raw.object != nil, let rows = raw["dailyUsageBuckets"].array else { throw GlassError.invalidReply }
        var days: [String: Double] = [:]
        var conflicts: Set<String> = []
        var incomplete = false
        for row in rows {
            guard let date = row["startDate"].string, UsageMath.isValidDate(date), let tokens = row["tokens"].number,
                  tokens >= 0, tokens <= 9_007_199_254_740_991, tokens.rounded(.down) == tokens else {
                incomplete = true; continue
            }
            if let old = days[date], old != tokens { conflicts.insert(date); incomplete = true }
            days[date] = tokens
        }
        for date in conflicts { days.removeValue(forKey: date) }
        return DailyUsage(days: days.keys.sorted().map { DailyRecord(date: $0, tokens: days[$0]) },
                          observedAt: now, incomplete: incomplete)
    }

    static func timestamp(_ value: JSONValue) -> Date? {
        guard let seconds = value.number, seconds >= 0, seconds <= 253_402_300_799 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    static func demoSnapshot(now: Date = Date()) -> UsageSnapshot {
        UsageSnapshot(identity: identity(.object(["id": .string("codex-glass-demo")])), plan: "plus", windows: [
            QuotaWindow(id: "codex:primary", minutes: 300, remaining: 68, resetsAt: now.addingTimeInterval(7980)),
            QuotaWindow(id: "codex:secondary", minutes: 10080, remaining: 82, resetsAt: now.addingTimeInterval(343800)),
            QuotaWindow(id: "reserve:primary", group: "reserve", scope: "gpt-reserve", model: "gpt-5.6-luna", minutes: 10080, remaining: 100, resetsAt: now.addingTimeInterval(500000))
        ], resets: ResetCredits(count: 1, expiresAt: now.addingTimeInterval(1209600)), observedAt: now)
    }

    static func demoDaily(now: Date = Date()) -> DailyUsage {
        let days = (0..<30).compactMap { i -> DailyRecord? in
            guard let date = Calendar.current.date(byAdding: .day, value: -i, to: now) else { return nil }
            return DailyRecord(date: UsageMath.dateString(date), tokens: i == 2 ? 0 : (1_400_000 + (sin(Double(i) * 1.7) + 1) * 1_600_000).rounded())
        }
        return DailyUsage(days: days.sorted { $0.date < $1.date }, observedAt: now)
    }
}

struct DiskStore {
    let directory: URL
    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
    }
    func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        let url = directory.appendingPathComponent(name + ".json")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber, size.intValue <= 4 * 1024 * 1024,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    func write<T: Encodable>(_ name: String, _ value: T) {
        let url = directory.appendingPathComponent(name + ".json")
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { /* A read-only home directory must not stop monitoring. */ }
    }
}
