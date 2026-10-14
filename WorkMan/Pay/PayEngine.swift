import Foundation

// MARK: - Inputs

/// The pay rules for one job. All money is in whole cents.
struct PayRules: Equatable {
    var overtimeEnabled: Bool = true
    /// Hours per week before overtime starts, in seconds (40 h by default).
    var weeklyOvertimeThresholdSeconds: Int = 40 * 3600
    /// 150 = time and a half.
    var overtimeMultiplierPercent: Int = 150
    /// Calendar weekday the work week starts on: 1 = Sunday … 7 = Saturday.
    var weekStartsOn: Int = 1
    /// 0 = exact. Otherwise punch-in and punch-out are rounded to the nearest N minutes.
    var roundingMinutes: Int = 0
    /// 1200 = 12.00 % estimated tax.
    var taxBasisPoints: Int = 1200
    var timeZone: TimeZone = .current
}

struct PayBreak: Equatable {
    var start: Date
    var end: Date
    var paid: Bool
}

/// One finished (or, for live numbers, "until now") shift.
struct PayShift: Equatable {
    var id: String = UUID().uuidString
    var start: Date
    var end: Date
    /// The pay rate saved on the shift, so a raise never changes old shifts.
    var rateCents: Int
    var tipsCents: Int = 0
    var breaks: [PayBreak] = []
}

// MARK: - Outputs

struct ShiftPay: Equatable {
    let id: String
    let workedSeconds: Int
    let regularSeconds: Int
    let overtimeSeconds: Int
    let tipsCents: Int
    /// Exact pay before rounding, in PayEngine.unitsPerCent units.
    let regularUnits: Int64
    let overtimeUnits: Int64

    var regularCents: Int { PayEngine.cents(fromUnits: regularUnits) }
    var overtimeCents: Int { PayEngine.cents(fromUnits: overtimeUnits) }
    var grossCents: Int { PayEngine.cents(fromUnits: regularUnits + overtimeUnits) + tipsCents }
}

struct PayTotals: Equatable {
    var workedSeconds = 0
    var regularSeconds = 0
    var overtimeSeconds = 0
    var regularCents = 0
    var overtimeCents = 0
    var tipsCents = 0
    var grossCents = 0
    var taxCents = 0
    var takeHomeCents = 0
}

// MARK: - Engine

/// Pure pay math. No SwiftUI, no SwiftData, so it is easy to test.
///
/// Money rule: pay is kept as exact "units" (seconds × rate in cents × multiplier %)
/// and only turned into cents at the very end, so small errors never pile up.
enum PayEngine {
    /// seconds per hour × 100 (for the multiplier percent).
    static let unitsPerCent: Int64 = 3600 * 100

    static func cents(fromUnits units: Int64) -> Int {
        // Round half up (units are never negative).
        Int((units + unitsPerCent / 2) / unitsPerCent)
    }

    /// Rounds a punch time to the nearest N minutes in the job's time zone.
    static func rounded(_ date: Date, toMinutes minutes: Int, in timeZone: TimeZone) -> Date {
        guard minutes > 0 else { return date }
        let step = Double(minutes * 60)
        let offset = Double(timeZone.secondsFromGMT(for: date))
        let local = date.timeIntervalSince1970 + offset
        let roundedLocal = (local / step).rounded(.toNearestOrAwayFromZero) * step
        return Date(timeIntervalSince1970: roundedLocal - offset)
    }

    /// Real elapsed time worked: punch-out − punch-in − unpaid breaks.
    /// Elapsed time is used (not clock time), so daylight-saving changes are handled.
    static func workedSeconds(start: Date, end: Date, breaks: [PayBreak], roundingMinutes: Int, timeZone: TimeZone) -> Int {
        let s = rounded(start, toMinutes: roundingMinutes, in: timeZone)
        let e = rounded(end, toMinutes: roundingMinutes, in: timeZone)
        guard e > s else { return 0 }
        var seconds = e.timeIntervalSince(s)
        for b in breaks where !b.paid {
            let overlap = min(b.end, e).timeIntervalSince(max(b.start, s))
            if overlap > 0 { seconds -= overlap }
        }
        return max(0, Int(seconds.rounded()))
    }

    /// Start of the work week that contains `date`.
    static func weekStart(for date: Date, rules: PayRules) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = rules.timeZone
        cal.firstWeekday = rules.weekStartsOn
        return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
    }

    /// Calculates pay for every shift. Overtime is counted per week:
    /// the hours past the weekly limit go to the latest shifts of that week.
    /// Results come back in the same order as the input.
    static func calculate(_ shifts: [PayShift], rules: PayRules) -> [ShiftPay] {
        var resultByID: [String: ShiftPay] = [:]
        let weeks = Dictionary(grouping: shifts) { weekStart(for: $0.start, rules: rules) }

        for (_, weekShifts) in weeks {
            var usedRegular = 0
            for shift in weekShifts.sorted(by: { $0.start < $1.start }) {
                let worked = workedSeconds(start: shift.start, end: shift.end, breaks: shift.breaks,
                                           roundingMinutes: rules.roundingMinutes, timeZone: rules.timeZone)
                var regular = worked
                var overtime = 0
                if rules.overtimeEnabled {
                    let left = max(0, rules.weeklyOvertimeThresholdSeconds - usedRegular)
                    regular = min(worked, left)
                    overtime = worked - regular
                }
                usedRegular += regular
                let rate = Int64(shift.rateCents)
                resultByID[shift.id] = ShiftPay(
                    id: shift.id,
                    workedSeconds: worked,
                    regularSeconds: regular,
                    overtimeSeconds: overtime,
                    tipsCents: shift.tipsCents,
                    regularUnits: Int64(regular) * rate * 100,
                    overtimeUnits: Int64(overtime) * rate * Int64(rules.overtimeMultiplierPercent)
                )
            }
        }
        return shifts.compactMap { resultByID[$0.id] }
    }

    /// Adds up shift results. Rounds to cents only once, at the end.
    static func totals(_ results: [ShiftPay], taxBasisPoints: Int) -> PayTotals {
        var t = PayTotals()
        var regularUnits: Int64 = 0
        var overtimeUnits: Int64 = 0
        for r in results {
            t.workedSeconds += r.workedSeconds
            t.regularSeconds += r.regularSeconds
            t.overtimeSeconds += r.overtimeSeconds
            t.tipsCents += r.tipsCents
            regularUnits += r.regularUnits
            overtimeUnits += r.overtimeUnits
        }
        t.regularCents = cents(fromUnits: regularUnits)
        t.overtimeCents = cents(fromUnits: overtimeUnits)
        t.grossCents = cents(fromUnits: regularUnits + overtimeUnits) + t.tipsCents
        t.taxCents = Int((Int64(t.grossCents) * Int64(taxBasisPoints) + 5_000) / 10_000)
        t.takeHomeCents = t.grossCents - t.taxCents
        return t
    }

    /// Take-home pay per hour, used for "this cost X hours of work".
    static func takeHomeCentsPerHour(rateCents: Int, taxBasisPoints: Int) -> Int {
        Int((Int64(rateCents) * Int64(10_000 - taxBasisPoints) + 5_000) / 10_000)
    }

    /// How many seconds of work an amount costs at the take-home rate.
    static func workSeconds(forCents amount: Int, rateCents: Int, taxBasisPoints: Int) -> Int {
        let perHour = takeHomeCentsPerHour(rateCents: rateCents, taxBasisPoints: taxBasisPoints)
        guard perHour > 0 else { return 0 }
        return Int((Double(amount) / Double(perHour) * 3600).rounded())
    }
}
