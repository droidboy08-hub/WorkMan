import Foundation
import SwiftData

/// Example data so the app can be tried right away. Turned on in setup.
enum SampleData {
    static func seed(job: Job, context: ModelContext, now: Date = .now) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        // Pay periods start two weeks back so there is history to look at.
        job.periodAnchor = cal.date(byAdding: .day, value: -14, to: today) ?? today

        // MARK: Shifts — past 20 days, a normal work week with one long Saturday (shows overtime).
        let startMinutes = [57, 2, 55, 0, 58, 4, 59]
        for offset in stride(from: -20, through: -1, by: 1) {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = cal.component(.weekday, from: day)   // 1 = Sunday
            if weekday == 1 || weekday == 4 { continue }      // off on Sunday and Wednesday
            let jitter = startMinutes[abs(offset) % startMinutes.count]
            let isSaturday = weekday == 7
            let start = jitter > 30 ? at(offset, isSaturday ? 9 : 8, jitter) : at(offset, isSaturday ? 10 : 9, jitter)
            let end = isSaturday ? at(offset, 20, 34) : at(offset, 17, 30 + (abs(offset) % 3) * 2)
            let shift = Shift(start: start, end: end, rateCents: job.hourlyRateCents,
                              tipsCents: weekday == 6 ? 1_200 : 0)
            context.insert(shift)
            job.shifts.append(shift)
            let b = BreakPeriod(start: at(offset, 12, 2), end: at(offset, 12, 31), paid: job.breaksPaid)
            context.insert(b)
            shift.breaks.append(b)
        }

        // MARK: Money
        let entries: [(Int, EntryKind, Int, MoneyCategory, String)] = [
            (0, .expense, 650, .food, "Chai & samosa"),
            (-1, .expense, 4_800, .fuel, "Gas"),
            (-2, .expense, 4_500, .bills, "Phone bill"),
            (-3, .expense, 6_230, .food, "Groceries"),
            (-4, .income, 6_000, .sideJob, "Helped at a friend's shop"),
            (-5, .expense, 3_240, .food, "Dinner out"),
            (-6, .income, 81_240, .pay, "Paycheck"),
            (-6, .expense, 1_800, .fun, "Movie"),
            (-8, .expense, 5_499, .shopping, "Shoes"),
            (-9, .expense, 4_100, .fuel, "Gas"),
            (-10, .expense, 975, .food, "Lunch"),
            (-12, .expense, 2_350, .health, "Pharmacy"),
        ]
        for (offset, kind, cents, category, note) in entries {
            context.insert(MoneyEntry(kind: kind, amountCents: cents, date: at(offset, 13, 15), category: category, note: note))
        }

        // MARK: Habits
        let created = cal.date(byAdding: .day, value: -20, to: today) ?? today
        let read = Habit(name: "Read 10 pages", symbol: "book", kind: .check, order: 0, createdAt: created)
        let water = Habit(name: "Drink water", symbol: "drop", kind: .count, goal: 8, order: 1, createdAt: created)
        let food = Habit(name: "Food under \(Fmt.money(2_000, job.currencyCode))", symbol: "fork.knife", kind: .foodUnder, goal: 2_000, order: 2, createdAt: created)
        let walk = Habit(name: "Walk 20 minutes", symbol: "figure.walk", kind: .check, order: 3, createdAt: created)
        [read, water, food, walk].forEach { context.insert($0) }

        for offset in -12 ... 0 {
            let day = at(offset, 0, 0)
            HabitLogic.add(read, day: day, count: 1, context: context)
            HabitLogic.add(water, day: day, count: offset == 0 ? 6 : 8, context: context)
            if offset != 0 && offset % 3 != 0 {
                HabitLogic.add(walk, day: day, count: 1, context: context)
            }
        }
        try? context.save()
    }

    /// Deletes everything (Settings › Start over).
    static func deleteAll(context: ModelContext) {
        // Children first, so nothing depends on cascade deletes.
        for b in (try? context.fetch(FetchDescriptor<BreakPeriod>())) ?? [] { context.delete(b) }
        for s in (try? context.fetch(FetchDescriptor<Shift>())) ?? [] { context.delete(s) }
        for c in (try? context.fetch(FetchDescriptor<HabitCheck>())) ?? [] { context.delete(c) }
        for job in (try? context.fetch(FetchDescriptor<Job>())) ?? [] { context.delete(job) }
        for entry in (try? context.fetch(FetchDescriptor<MoneyEntry>())) ?? [] { context.delete(entry) }
        for habit in (try? context.fetch(FetchDescriptor<Habit>())) ?? [] { context.delete(habit) }
        try? context.save()
    }
}
