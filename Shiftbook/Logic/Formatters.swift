import Foundation

enum Fmt {
    private static var moneyFormatters: [String: NumberFormatter] = [:]

    private static func moneyFormatter(_ code: String) -> NumberFormatter {
        if let f = moneyFormatters[code] { return f }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        moneyFormatters[code] = f
        return f
    }

    /// 1500 → "$15.00"
    static func money(_ cents: Int, _ code: String) -> String {
        let value = NSDecimalNumber(decimal: Decimal(cents) / 100)
        return moneyFormatter(code).string(from: value) ?? "\(Double(cents) / 100)"
    }

    /// Symbol only, e.g. "$" or "₹".
    static func currencySymbol(_ code: String) -> String {
        moneyFormatter(code).currencySymbol ?? code
    }

    /// 29280 → "8h 08m". Worked time is rounded down, so the app never shows more than you worked.
    static func hm(_ seconds: Int, roundToNearest: Bool = false) -> String {
        let minutes = roundToNearest ? (seconds + 30) / 60 : seconds / 60
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h " + String(format: "%02dm", m)
    }

    /// 13338 → "3:42:18"
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// "8:57 AM"
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "Wednesday, Oct 14"
    static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// "Oct 4 – 17" or "Sep 28 – Oct 11"
    static func range(_ interval: DateInterval) -> String {
        let cal = Calendar.current
        let lastDay = interval.end.addingTimeInterval(-1)
        let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
        let sameMonth = cal.isDate(interval.start, equalTo: lastDay, toGranularity: .month)
        let end = sameMonth ? lastDay.formatted(.dateTime.day()) : lastDay.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    /// Parses what the user typed ("15", "15.5", "15,50") into cents.
    static func cents(from text: String) -> Int? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned) else { return nil }
        var result = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// 1500 → "15.00" for text fields.
    static func plain(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100)
    }
}
