import SwiftUI

/// What the app last told the widget.
///
/// Every field is optional and every accessor has a fallback. The widget
/// bundle ships with the app, so the two are normally in step — but during a
/// phased App Store release an old widget can be handed a payload written by a
/// new build, and a decode failure on the home screen shows a blank rectangle
/// the user cannot diagnose or dismiss. Degrading is always better than
/// failing here.
///
/// Mirrors `buildWidgetPayload` in `lib/features/widget/widget_payload.dart`,
/// which is the single source of truth for every value below — including the
/// colours, so that the five weather palettes are not transcribed into a
/// second language where they would drift.
struct WidgetPayload: Decodable {
    struct Palette: Decodable {
        let background: String?
        let surface: String?
        let text: String?
        let textSecondary: String?
        let primary: String?
    }

    let schema: Int?
    let localDate: String?
    let weatherCode: Int?
    let condition: String?
    let tempHigh: Int?
    let tempLow: Int?
    let unit: String?
    let matchCount: Int?
    let matches: [String]?
    let colors: Palette?

    enum CodingKeys: String, CodingKey {
        case schema
        case localDate = "local_date"
        case weatherCode = "weather_code"
        case condition
        case tempHigh = "temp_high"
        case tempLow = "temp_low"
        case unit
        case matchCount = "match_count"
        case matches
        case colors
    }

    /// The highest payload schema this build understands.
    static let supportedSchema = 1

    static let appGroupId = "group.com.outabout.outabout"
    static let storageKey = "outabout_widget_payload"

    /// Reads the shared store, or nil when there is nothing usable.
    ///
    /// nil covers three different situations that all look the same to the
    /// user and all deserve the same answer — "open the app": the App Group is
    /// not provisioned, the app has never run, or the stored value cannot be
    /// read by this build.
    static func load() -> WidgetPayload? {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let raw = defaults.string(forKey: storageKey),
              let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data)
        else { return nil }

        // A payload from a newer app than this widget. Showing its temperature
        // while silently misreading a field that changed meaning is worse than
        // asking the user to open the app.
        if let schema = payload.schema, schema > supportedSchema { return nil }
        return payload
    }

    // MARK: - Presentation

    /// True when the payload describes a day that is no longer today.
    ///
    /// Decided here rather than stamped by the app, because it changes without
    /// anything being written: a payload correct at 23:59 is stale at 00:01,
    /// and nothing pushes to the widget overnight.
    func isStale(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let localDate else { return false }
        return localDate != Self.isoFormatter.string(from: now)
    }

    /// "Fri 22 Aug" for the staleness note, or nil if the date is unreadable.
    func shortDateLabel() -> String? {
        guard let localDate,
              let date = Self.isoFormatter.date(from: localDate) else { return nil }
        return Self.shortFormatter.string(from: date)
    }

    var temperatureLine: String {
        guard let high = tempHigh else { return "—" }
        let suffix = (unit == "F") ? "°F" : "°C"
        guard let low = tempLow else { return "\(high)\(suffix)" }
        return "\(high)° / \(low)\(suffix)"
    }

    var count: Int { matchCount ?? 0 }

    /// "3 match today" — the small size's entire message.
    var matchSummary: String {
        switch count {
        case 0: return "Nothing matches today"
        case 1: return "1 match today"
        default: return "\(count) match today"
        }
    }

    /// Names to list, and how many were left out.
    var listedMatches: [String] { matches ?? [] }
    var overflowCount: Int { max(0, count - listedMatches.count) }

    // MARK: - Colours

    /// The palette the app resolved, with a readable fallback per slot.
    ///
    /// The fallback is only reachable for a payload missing its colours
    /// entirely, which means a build mismatch — so it is deliberately neutral
    /// rather than one of the five weather themes, and it follows the system
    /// appearance instead of guessing at the weather.
    func color(_ keyPath: KeyPath<Palette, String?>, fallback: Color) -> Color {
        guard let hex = colors?[keyPath: keyPath],
              let parsed = Color(hex: hex) else { return fallback }
        return parsed
    }

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter
    }()
}

extension Color {
    /// Parses `#RRGGBB`. Six digits only — the Dart side never emits alpha,
    /// because an eight-digit string is read as ARGB or RGBA depending on who
    /// wrote it, and there is no way to tell which from the string alone.
    init?(hex: String) {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// SF Symbol for a Tomorrow.io weather code.
///
/// The only weather knowledge that lives in Swift. The *name* of the condition
/// is resolved in Dart and shipped in the payload; this maps the same code to
/// a glyph, which has no Dart equivalent to drift from.
/// https://docs.tomorrow.io/reference/data-layers-weather-codes
func weatherSymbol(for code: Int?) -> String {
    guard let code else { return "sun.max.fill" }
    switch code {
    case 8000...8999: return "cloud.bolt.rain.fill"
    case 7000...7999: return "cloud.sleet.fill"
    case 6000...6999: return "cloud.sleet.fill"
    case 5000...5999: return "cloud.snow.fill"
    case 4000...4999: return "cloud.rain.fill"
    case 2000...2999: return "cloud.fog.fill"
    case 1001, 1102: return "cloud.fill"
    case 1100...1101: return "cloud.sun.fill"
    default: return "sun.max.fill"
    }
}
