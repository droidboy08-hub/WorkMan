import Foundation
import SwiftData

enum HabitStatus {
    case done        // checked off
    case notDone     // not yet
    case onTrack     // automatic habit, today, still fine
    case broken      // automatic habit, rule broken

    var counts: Bool { self == .done || self == .onTrack }
}

enum HabitLogic {
    static var cal: Calendar { Calendar.current }

    static func count(_ habit: Habit, on day: Date) -> Int {
        habit.checks.first { cal.isDate($0.day, inSameDayAs: day) }?.count ?? 0
    }

    static func spentCents(on day: Date, entries: [MoneyEntry], category: MoneyCategory? = nil) -> Int {
        entries
            .filter { $0.kind == .expense && cal.isDate($0.date, inSameDayAs: day) }
            .filter { category == nil || $0.category == category }
            .reduce(0) { $0 + $1.amountCents }
    }

    static func status(_ habit: Habit, on day: Date, entries: [MoneyEntry], now: Date = .now) -> HabitStatus {
        let isToday = cal.isDate(day, inSameDayAs: now)
        switch habit.kind {
        case .check:
            return count(habit, on: day) >= 1 ? .done : .notDone
        case .count:
            return count(habit, on: day) >= max(1, habit.goal) ? .done : .notDone
        case .noSpend:
            if spentCents(on: day, entries: entries) > 0 { return .broken }
            return isToday ? .onTrack : .done
        case .foodUnder:
            if spentCents(on: day, entries: entries, category: .food) > habit.goal { return .broken }
            return isToday ? .onTrack : .done
        }
    }

    /// Days in a row. Today only counts once it is done, so an unfinished today never breaks the streak.
    static func streak(_ habit: Habit, entries: [MoneyEntry], now: Date = .now) -> Int {
        let created = cal.startOfDay(for: habit.createdAt)
        var day = cal.startOfDay(for: now)
        if !status(habit, on: day, entries: entries, now: now).counts {
            guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while day >= created, n < 3650, status(habit, on: day, entries: entries, now: now).counts {
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// Yes/No habits: tap to check, tap again to undo.
    /// Count habits: each tap adds one; after the goal it starts over at zero.
    static func tap(_ habit: Habit, on day: Date, context: ModelContext) {
        let start = cal.startOfDay(for: day)
        let existing = habit.checks.first { cal.isDate($0.day, inSameDayAs: start) }
        switch habit.kind {
        case .check:
            if let existing {
                habit.checks.removeAll { $0 === existing }
                context.delete(existing)
            } else {
                add(habit, day: start, count: 1, context: context)
            }
        case .count:
            let goal = max(1, habit.goal)
            if let existing {
                if existing.count >= goal {
                    habit.checks.removeAll { $0 === existing }
                    context.delete(existing)
                } else {
                    existing.count += 1
                }
            } else {
                add(habit, day: start, count: 1, context: context)
            }
        case .noSpend, .foodUnder:
            break // automatic
        }
        try? context.save()
    }

    static func add(_ habit: Habit, day: Date, count: Int, context: ModelContext) {
        let check = HabitCheck(day: cal.startOfDay(for: day), count: count)
        context.insert(check)
        habit.checks.append(check)
    }
}
