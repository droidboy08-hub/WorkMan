import Foundation
import SwiftData
import SwiftUI

// MARK: - Job

enum PayPeriodKind: String, CaseIterable, Identifiable {
    case weekly, biweekly, monthly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        }
    }
}

@Model
final class Job {
    var name: String
    var hourlyRateCents: Int
    var currencyCode: String
    var payPeriodRaw: String
    /// Calendar weekday: 1 = Sunday … 7 = Saturday.
    var weekStartsOn: Int
    var overtimeEnabled: Bool
    var overtimeThresholdHours: Int
    var overtimeMultiplierPercent: Int
    var breaksPaid: Bool
    var roundingMinutes: Int
    var taxBasisPoints: Int
    /// First day of the first pay period (used for "every 2 weeks").
    var periodAnchor: Date
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Shift.job)
    var shifts: [Shift] = []

    init(name: String,
         hourlyRateCents: Int,
         currencyCode: String = "USD",
         payPeriod: PayPeriodKind = .biweekly,
         weekStartsOn: Int = 1,
         overtimeEnabled: Bool = true,
         overtimeThresholdHours: Int = 40,
         overtimeMultiplierPercent: Int = 150,
         breaksPaid: Bool = false,
         roundingMinutes: Int = 0,
         taxBasisPoints: Int = 1200,
         periodAnchor: Date = .now) {
        self.name = name
        self.hourlyRateCents = hourlyRateCents
        self.currencyCode = currencyCode
        self.payPeriodRaw = payPeriod.rawValue
        self.weekStartsOn = weekStartsOn
        self.overtimeEnabled = overtimeEnabled
        self.overtimeThresholdHours = overtimeThresholdHours
        self.overtimeMultiplierPercent = overtimeMultiplierPercent
        self.breaksPaid = breaksPaid
        self.roundingMinutes = roundingMinutes
        self.taxBasisPoints = taxBasisPoints
        self.periodAnchor = periodAnchor
        self.createdAt = .now
    }

    var payPeriod: PayPeriodKind {
        get { PayPeriodKind(rawValue: payPeriodRaw) ?? .biweekly }
        set { payPeriodRaw = newValue.rawValue }
    }

    var rules: PayRules {
        var r = PayRules()
        r.overtimeEnabled = overtimeEnabled
        r.weeklyOvertimeThresholdSeconds = overtimeThresholdHours * 3600
        r.overtimeMultiplierPercent = overtimeMultiplierPercent
        r.weekStartsOn = weekStartsOn
        r.roundingMinutes = roundingMinutes
        r.taxBasisPoints = taxBasisPoints
        r.timeZone = .current
        return r
    }

    var runningShift: Shift? { shifts.first { $0.end == nil } }
}

// MARK: - Shift and breaks

@Model
final class Shift {
    var uid: String = UUID().uuidString
    var start: Date
    /// nil while the user is still punched in.
    var end: Date?
    /// Pay rate saved on the shift, so a raise never changes old shifts.
    var rateCents: Int
    var tipsCents: Int
    var note: String
    var edited: Bool
    var job: Job?

    @Relationship(deleteRule: .cascade, inverse: \BreakPeriod.shift)
    var breaks: [BreakPeriod] = []

    init(start: Date, end: Date? = nil, rateCents: Int, tipsCents: Int = 0, note: String = "", edited: Bool = false) {
        self.start = start
        self.end = end
        self.rateCents = rateCents
        self.tipsCents = tipsCents
        self.note = note
        self.edited = edited
    }

    var isRunning: Bool { end == nil }
    var runningBreak: BreakPeriod? { breaks.first { $0.end == nil } }
    var sortedBreaks: [BreakPeriod] { breaks.sorted { $0.start < $1.start } }

    /// The shift as the pay engine sees it. A running shift or break ends at `now`.
    func payShift(now: Date = .now) -> PayShift {
        PayShift(id: uid,
                 start: start,
                 end: end ?? now,
                 rateCents: rateCents,
                 tipsCents: tipsCents,
                 breaks: breaks.map { PayBreak(start: $0.start, end: $0.end ?? now, paid: $0.paid) })
    }

    var unpaidBreakSeconds: Int {
        breaks.filter { !$0.paid }.reduce(0) { sum, b in
            sum + max(0, Int((b.end ?? .now).timeIntervalSince(b.start)))
        }
    }
}

@Model
final class BreakPeriod {
    var start: Date
    var end: Date?
    var paid: Bool
    var shift: Shift?

    init(start: Date, end: Date? = nil, paid: Bool) {
        self.start = start
        self.end = end
        self.paid = paid
    }
}

// MARK: - Money

enum EntryKind: String, CaseIterable, Identifiable {
    case expense, income
    var id: String { rawValue }
    var title: String { self == .expense ? "Expense" : "Income" }
}

enum MoneyCategory: String, CaseIterable, Identifiable {
    case food, fuel, rent, bills, shopping, fun, health, otherExpense
    case pay, sideJob, gift, otherIncome

    var id: String { rawValue }

    var kind: EntryKind {
        switch self {
        case .pay, .sideJob, .gift, .otherIncome: return .income
        default: return .expense
        }
    }

    var title: String {
        switch self {
        case .food: return "Food"
        case .fuel: return "Fuel"
        case .rent: return "Rent"
        case .bills: return "Bills"
        case .shopping: return "Shopping"
        case .fun: return "Fun"
        case .health: return "Health"
        case .otherExpense: return "Other"
        case .pay: return "Paycheck"
        case .sideJob: return "Side job"
        case .gift: return "Gift"
        case .otherIncome: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .fuel: return "fuelpump"
        case .rent: return "house"
        case .bills: return "doc.text"
        case .shopping: return "bag"
        case .fun: return "ticket"
        case .health: return "cross.case"
        case .otherExpense: return "ellipsis.circle"
        case .pay: return "banknote"
        case .sideJob: return "hammer"
        case .gift: return "gift"
        case .otherIncome: return "plus.circle"
        }
    }

    var color: Color {
        switch self {
        case .food: return Theme.coral
        case .fuel: return Theme.catBlue
        case .rent: return Theme.catGrey
        case .bills: return Theme.catGrey
        case .shopping: return Theme.amber
        case .fun: return Theme.catPurple
        case .health: return Theme.green
        case .otherExpense: return Theme.muted
        case .pay, .sideJob, .gift, .otherIncome: return Theme.green
        }
    }

    static func all(for kind: EntryKind) -> [MoneyCategory] { allCases.filter { $0.kind == kind } }
}

@Model
final class MoneyEntry {
    var kindRaw: String
    var amountCents: Int
    var date: Date
    var categoryRaw: String
    var note: String
    var createdAt: Date

    init(kind: EntryKind, amountCents: Int, date: Date, category: MoneyCategory, note: String = "") {
        self.kindRaw = kind.rawValue
        self.amountCents = amountCents
        self.date = date
        self.categoryRaw = category.rawValue
        self.note = note
        self.createdAt = .now
    }

    var kind: EntryKind { EntryKind(rawValue: kindRaw) ?? .expense }
    var category: MoneyCategory { MoneyCategory(rawValue: categoryRaw) ?? .otherExpense }
    var title: String { note.isEmpty ? category.title : note }
}

// MARK: - Habits

enum HabitKind: String, CaseIterable, Identifiable {
    case check, count, noSpend, foodUnder
    var id: String { rawValue }

    var title: String {
        switch self {
        case .check: return "Yes / No"
        case .count: return "Count"
        case .noSpend: return "No-spend day"
        case .foodUnder: return "Food under a limit"
        }
    }

    /// Automatic habits check themselves from your spending.
    var isAuto: Bool { self == .noSpend || self == .foodUnder }
}

@Model
final class Habit {
    var name: String
    var symbol: String
    var kindRaw: String
    /// Count goal (for count habits) or money limit in cents (for "food under").
    var goal: Int
    var order: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitCheck.habit)
    var checks: [HabitCheck] = []

    init(name: String, symbol: String, kind: HabitKind, goal: Int = 1, order: Int = 0, createdAt: Date = .now) {
        self.name = name
        self.symbol = symbol
        self.kindRaw = kind.rawValue
        self.goal = goal
        self.order = order
        self.createdAt = createdAt
    }

    var kind: HabitKind { HabitKind(rawValue: kindRaw) ?? .check }
}

@Model
final class HabitCheck {
    /// Start of the day this check belongs to.
    var day: Date
    var count: Int
    var habit: Habit?

    init(day: Date, count: Int) {
        self.day = day
        self.count = count
    }
}
