import Foundation
import SwiftData

/// Punch in, breaks and punch out. Times are saved the moment the button is tapped.
/// Relationships are always changed on the parent's list (job.shifts, shift.breaks),
/// so every screen that shows that list refreshes right away.
enum ShiftActions {
    @discardableResult
    static func punchIn(job: Job, context: ModelContext, at date: Date = .now) -> Shift {
        // A quick double tap must never create two running shifts.
        if let running = job.runningShift { return running }
        let shift = Shift(start: date, rateCents: job.hourlyRateCents)
        context.insert(shift)
        job.shifts.append(shift)
        try? context.save()
        return shift
    }

    static func startBreak(_ shift: Shift, job: Job, context: ModelContext, at date: Date = .now) {
        guard shift.isRunning, shift.runningBreak == nil else { return }
        let b = BreakPeriod(start: date, paid: job.breaksPaid)
        context.insert(b)
        shift.breaks.append(b)
        try? context.save()
    }

    static func endBreak(_ shift: Shift, context: ModelContext, at date: Date = .now) {
        shift.runningBreak?.end = date
        try? context.save()
    }

    static func punchOut(_ shift: Shift, context: ModelContext, at date: Date = .now) {
        if let b = shift.runningBreak { b.end = date }
        shift.end = date
        try? context.save()
    }

    /// A shift typed in by hand (forgot to punch in). Marked "edited" so the record stays honest.
    static func addManual(job: Job, start: Date, end: Date, unpaidBreakMinutes: Int, tipsCents: Int, note: String, context: ModelContext) {
        let shift = Shift(start: start, end: end, rateCents: job.hourlyRateCents, tipsCents: tipsCents, note: note, edited: true)
        context.insert(shift)
        job.shifts.append(shift)
        if unpaidBreakMinutes > 0 {
            let mid = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
            let b = BreakPeriod(start: mid, end: mid.addingTimeInterval(Double(unpaidBreakMinutes) * 60), paid: false)
            context.insert(b)
            shift.breaks.append(b)
        }
        try? context.save()
    }
}
