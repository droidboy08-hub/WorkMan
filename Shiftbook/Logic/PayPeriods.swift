import Foundation

/// Pay period dates and pay summaries for a job.
enum PayPeriods {
    static func calendar(for job: Job) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.firstWeekday = job.weekStartsOn
        return cal
    }

    static func interval(containing date: Date, job: Job) -> DateInterval {
        let cal = calendar(for: job)
        let fallback = DateInterval(start: cal.startOfDay(for: date), duration: 86_400)
        switch job.payPeriod {
        case .weekly:
            return cal.dateInterval(of: .weekOfYear, for: date) ?? fallback
        case .monthly:
            return cal.dateInterval(of: .month, for: date) ?? fallback
        case .biweekly:
            let anchor = PayEngine.weekStart(for: job.periodAnchor, rules: job.rules)
            let week = PayEngine.weekStart(for: date, rules: job.rules)
            let days = cal.dateComponents([.day], from: anchor, to: week).day ?? 0
            let index = Int((Double(days) / 14.0).rounded(.down))
            guard let start = cal.date(byAdding: .day, value: index * 14, to: anchor),
                  let end = cal.date(byAdding: .day, value: 14, to: start) else { return fallback }
            return DateInterval(start: start, end: end)
        }
    }

    /// The period before (-1) or after (+1) the given one.
    static func neighbor(of interval: DateInterval, direction: Int, job: Job) -> DateInterval {
        let probe = direction < 0 ? interval.start.addingTimeInterval(-3600) : interval.end.addingTimeInterval(3600)
        return self.interval(containing: probe, job: job)
    }

    /// Pay for every shift of the job (a running shift counts up to `now`).
    /// Overtime needs the whole week, so all shifts are calculated together.
    static func results(for job: Job, now: Date = .now) -> [String: ShiftPay] {
        let pays = PayEngine.calculate(job.shifts.map { $0.payShift(now: now) }, rules: job.rules)
        return Dictionary(pays.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Live pay for the running shift. Only this week's shifts are needed for overtime.
    static func liveResult(for shift: Shift, job: Job, now: Date) -> ShiftPay? {
        let rules = job.rules
        let week = PayEngine.weekStart(for: shift.start, rules: rules)
        let sameWeek = job.shifts.filter { PayEngine.weekStart(for: $0.start, rules: rules) == week }
        return PayEngine.calculate(sameWeek.map { $0.payShift(now: now) }, rules: rules)
            .first { $0.id == shift.uid }
    }

    /// Hours worked so far this week (finished shifts and the running one).
    static func weekRegularSeconds(job: Job, now: Date) -> Int {
        let rules = job.rules
        let week = PayEngine.weekStart(for: now, rules: rules)
        let shifts = job.shifts.filter { PayEngine.weekStart(for: $0.start, rules: rules) == week }
        let pays = PayEngine.calculate(shifts.map { $0.payShift(now: now) }, rules: rules)
        return pays.reduce(0) { $0 + $1.workedSeconds }
    }
}
