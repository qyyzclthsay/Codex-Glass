import AppKit
import SwiftUI
import CodexGlassCore

enum AppResources {
    static let bundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("CodexGlass_CodexGlass.bundle"),
           let result = Bundle(url: url) { return result }
        return Bundle.module
    }()
}

enum Copy {
    private static let messages: [String: [String: String]] = {
        guard let url = AppResources.bundle.url(forResource: "messages", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return result
    }()

    static func text(_ key: String, _ language: String) -> String {
        messages[language]?[key] ?? messages["en"]?[key] ?? key
    }

    static func platform(_ english: String, _ simplified: String, _ traditional: String, _ language: String) -> String {
        language == "zh" ? simplified : language == "zh-TW" ? traditional : english
    }

    static func period(_ window: QuotaWindow?, _ language: String) -> String {
        guard let window else { return "Codex" }
        if window.minutes == 10080 { return text("week", language) }
        if window.minutes == 300 { return text("five", language) }
        if let minutes = window.minutes { return "\(Int(minutes)) \(text("minutes", language))" }
        return "Codex"
    }

    static func countdown(_ window: QuotaWindow, now: Date, language: String) -> String {
        guard let reset = window.resetsAt else { return text("noReset", language) }
        let minutes = Int(ceil(reset.timeIntervalSince(now) / 60))
        guard minutes > 0 else { return text("resetting", language) }
        let days = minutes / 1440, hours = minutes % 1440 / 60, remainder = minutes % 60
        let interval = days > 0 ? "\(days) \(text("days", language)) \(hours) \(text("hours", language))" :
            hours > 0 ? "\(hours) \(text("hours", language)) \(remainder) \(text("minutes", language))" :
            "\(remainder) \(text("minutes", language))"
        return interval + " " + text("resetsIn", language)
    }

    static let dayFormatter: DateFormatter = {
        let result = DateFormatter()
        result.locale = Locale(identifier: "en_US_POSIX")
        result.calendar = Calendar(identifier: .gregorian)
        result.dateFormat = "yyyy-MM-dd"
        result.isLenient = false
        return result
    }()

    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func date(_ value: String) -> Date? { dayFormatter.date(from: value) }
}

extension NSColor {
    convenience init(glassHex: String) {
        let cleaned = glassHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(cleaned, radix: 16) ?? 0x4F8DF7
        self.init(srgbRed: CGFloat((value >> 16) & 255) / 255,
                  green: CGFloat((value >> 8) & 255) / 255,
                  blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    var glassHex: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#4F8DF7" }
        return String(format: "#%02X%02X%02X", Int(round(rgb.redComponent * 255)),
                      Int(round(rgb.greenComponent * 255)), Int(round(rgb.blueComponent * 255)))
    }
}

extension AppSettings {
    var accent: Color { Color(nsColor: NSColor(glassHex: accentColor ?? "#4F8DF7")) }
    var ringAccent: NSColor { NSColor(glassHex: accentColor ?? "#2EC9A0") }
    var scheme: ColorScheme? { theme == "dark" ? .dark : theme == "light" ? .light : nil }
}

struct IconButton: View {
    var symbol: String
    var label: String
    var active = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 29, height: 29)
                .background(active ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.accentColor : Color.secondary)
        .help(label)
        .accessibilityLabel(label)
    }
}

struct Card<Content: View>: View {
    var highlighted = false
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? Color.accentColor.opacity(0.065) : Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(highlighted ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.13), lineWidth: 1))
    }
}
