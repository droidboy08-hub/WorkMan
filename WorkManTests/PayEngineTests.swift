import Foundation
import Testing
@testable import WorkMan

/// Every example from the project plan, plus the tricky cases.
/// Run them in Xcode with Product › Test (⌘U).
struct PayEngineTests {
    let tz = TimeZone(identifier: "America/New_York")!

    var rules: PayRules {
        var r = PayRules()
        r.timeZone = tz
        return r
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func shift(_ d: Int, _ h1: Int, _ m1: Int, to d2: Int, _ h2: Int, _ m2: Int,
               rate: Int = 1500, breaks: [PayBreak] = [], month: Int = 10) -> PayShift {
        PayShift(start: date(2026, month, d, h1, m1), end: date(2026, month, d2, h2, m2),
                 rateCents: rate, breaks: breaks)
    }

    // Plan example 1: 8:57 AM – 5:34 PM, 29 min unpaid break, $15/hr = $122.00
    @Test func planExampleOneShift() {
        let br = PayBreak(start: date(2026, 10, 13, 12, 2), end: date(2026, 10, 13, 12, 31), paid: false)
        let s = shift(13, 8, 57, to: 13, 17, 34, breaks: [br])
        let r = PayEngine.calculate([s], rules: rules)[0]
        #expect(r.workedSeconds == 488 * 60)   // 8 h 08 min
        #expect(r.grossCents == 12_200)
        #expect(r.overtimeSeconds == 0)
    }

    // Plan: same shift with 15-minute rounding = 481 min = $120.25
    @Test func fifteenMinuteRounding() {
        var r15 = rules
        r15.roundingMinutes = 15
        let br = PayBreak(start: date(2026, 10, 13, 12, 2), end: date(2026, 10, 13, 12, 31), paid: false)
        let s = shift(13, 8, 57, to: 13, 17, 34, breaks: [br])
        let r = PayEngine.calculate([s], rules: r15)[0]
        #expect(r.workedSeconds == 481 * 60)
        #expect(r.grossCents == 12_025)
    }

    // Plan example 2: 44-hour week at $15 = $690.00 gross, $607.20 after 12% tax
    @Test func planExampleWeekWithOvertime() {
        let shifts = [12, 13, 14, 15].map { shift($0, 8, 0, to: $0, 19, 0) }   // 4 × 11 h, Mon–Thu
        let results = PayEngine.calculate(shifts, rules: rules)
        let t = PayEngine.totals(results, taxBasisPoints: 1200)
        #expect(t.regularSeconds == 40 * 3600)
        #expect(t.overtimeSeconds == 4 * 3600)
        #expect(t.regularCents == 60_000)
        #expect(t.overtimeCents == 9_000)
        #expect(t.grossCents == 69_000)
        #expect(t.taxCents == 8_280)
        #expect(t.takeHomeCents == 60_720)
        // Overtime lands on the last shift of the week (Thursday: 7 h regular + 4 h overtime).
        #expect(results[3].regularSeconds == 7 * 3600)
        #expect(results[3].overtimeSeconds == 4 * 3600)
        #expect(results[3].grossCents == 19_500)
    }

    @Test func overtimeTurnedOff() {
        var noOT = rules
        noOT.overtimeEnabled = false
        let shifts = [12, 13, 14, 15].map { shift($0, 8, 0, to: $0, 19, 0) }
        let t = PayEngine.totals(PayEngine.calculate(shifts, rules: noOT), taxBasisPoints: 0)
        #expect(t.overtimeSeconds == 0)
        #expect(t.grossCents == 66_000)
    }

    @Test func paidBreakIsNotSubtracted() {
        let br = PayBreak(start: date(2026, 10, 13, 12, 0), end: date(2026, 10, 13, 12, 30), paid: true)
        let r = PayEngine.calculate([shift(13, 9, 0, to: 13, 17, 0, breaks: [br])], rules: rules)[0]
        #expect(r.workedSeconds == 8 * 3600)
        #expect(r.grossCents == 12_000)
    }

    // Shift past midnight belongs to the day it started.
    @Test func shiftPastMidnight() {
        let br = PayBreak(start: date(2026, 10, 14, 2, 0), end: date(2026, 10, 14, 2, 30), paid: false)
        let s = shift(13, 22, 0, to: 14, 6, 0, breaks: [br])
        let r = PayEngine.calculate([s], rules: rules)[0]
        #expect(r.workedSeconds == 7 * 3600 + 30 * 60)
        #expect(r.grossCents == 11_250)
    }

    // Clocks go back on Nov 1, 2026 in New York: 10 PM → 6 AM is 9 real hours, not 8.
    @Test func daylightSavingChange() {
        let s = PayShift(start: date(2026, 10, 31, 22, 0), end: date(2026, 11, 1, 6, 0), rateCents: 1500)
        let r = PayEngine.calculate([s], rules: rules)[0]
        #expect(r.workedSeconds == 9 * 3600)
        #expect(r.grossCents == 13_500)
    }

    // A raise mid-week: old shifts keep $15, the new shift uses $20, overtime at $30.
    @Test func payRateChangeMidWeek() {
        let old = [12, 13, 14].map { shift($0, 8, 0, to: $0, 20, 0, rate: 1500) }   // 36 h
        let new = shift(15, 9, 0, to: 15, 17, 0, rate: 2000)                         // 8 h
        let results = PayEngine.calculate(old + [new], rules: rules)
        let t = PayEngine.totals(results, taxBasisPoints: 0)
        #expect(t.regularCents == 54_000 + 8_000)
        #expect(t.overtimeCents == 12_000)
        #expect(t.grossCents == 74_000)
        #expect(results[3].regularSeconds == 4 * 3600)
        #expect(results[3].overtimeSeconds == 4 * 3600)
    }

    // Overtime resets when the work week starts. 38 h + 8 h across Sat → Sun.
    @Test func weekStartSetting() {
        let shifts = [
            shift(6, 8, 0, to: 6, 18, 0),    // Tue 10 h
            shift(7, 8, 0, to: 7, 18, 0),    // Wed 10 h
            shift(8, 8, 0, to: 8, 18, 0),    // Thu 10 h
            shift(10, 9, 0, to: 10, 17, 0),  // Sat 8 h  → 38 h
            shift(11, 9, 0, to: 11, 17, 0),  // Sun 8 h
        ]
        // Week starts Sunday: Sunday is a new week, so no overtime.
        let sunday = PayEngine.totals(PayEngine.calculate(shifts, rules: rules), taxBasisPoints: 0)
        #expect(sunday.overtimeSeconds == 0)
        #expect(sunday.grossCents == 69_000)

        // Week starts Monday: all 46 h are one week, 6 h overtime.
        var monday = rules
        monday.weekStartsOn = 2
        let t = PayEngine.totals(PayEngine.calculate(shifts, rules: monday), taxBasisPoints: 0)
        #expect(t.overtimeSeconds == 6 * 3600)
        #expect(t.grossCents == 73_500)
    }

    @Test func tipsAreAddedOnTop() {
        var s = shift(13, 9, 0, to: 13, 17, 0)
        s.tipsCents = 1_250
        let r = PayEngine.calculate([s], rules: rules)[0]
        #expect(r.grossCents == 12_000 + 1_250)
    }

    // "This $45 dinner = about 3 h 25 min of work" at $15/hr with 12% tax.
    @Test func costInWorkHours() {
        #expect(PayEngine.takeHomeCentsPerHour(rateCents: 1500, taxBasisPoints: 1200) == 1_320)
        let seconds = PayEngine.workSeconds(forCents: 4_500, rateCents: 1500, taxBasisPoints: 1200)
        #expect((seconds + 30) / 60 == 3 * 60 + 25)
    }

    @Test func endBeforeStartPaysNothing() {
        let s = PayShift(start: date(2026, 10, 13, 17, 0), end: date(2026, 10, 13, 9, 0), rateCents: 1500)
        #expect(PayEngine.calculate([s], rules: rules)[0].grossCents == 0)
    }
}
