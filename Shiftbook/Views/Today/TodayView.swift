import SwiftUI
import SwiftData
import UIKit

struct TodayView: View {
    let job: Job
    @Environment(\.modelContext) var context
    @Query(sort: \MoneyEntry.date, order: .reverse) var entries: [MoneyEntry]
    @Query(sort: \Habit.order) var habits: [Habit]

    @State var showSettings = false
    @State var showAddExpense = false
    @State var finishedShift: Shift?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScreenHeader(small: Fmt.longDay(.now), title: "Today") {
                    RoundIconButton(symbol: "slider.horizontal.3", label: "Settings") { showSettings = true }
                }
                PunchCard(job: job) { finishedShift = $0 }
                if !habits.isEmpty { habitsCard }
                spentCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.paper.ignoresSafeArea())
        .sheet(isPresented: $showSettings) { SettingsView(job: job) }
        .sheet(isPresented: $showAddExpense) { AddEntrySheet(job: job, startKind: .expense) }
        .sheet(item: $finishedShift) { ShiftSummarySheet(shift: $0, job: job) }
    }

    // MARK: Habits strip

    var habitsCard: some View {
        let now = Date.now
        let done = habits.filter { HabitLogic.status($0, on: now, entries: entries, now: now).counts }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Habits")
                Spacer()
                Text("\(done) of \(habits.count)")
                    .font(AppFont.num(12))
                    .foregroundStyle(Theme.muted)
            }
            FlowLayout(spacing: 6) {
                ForEach(habits) { habit in
                    HabitChip(habit: habit, status: HabitLogic.status(habit, on: now, entries: entries, now: now),
                              count: HabitLogic.count(habit, on: now)) {
                        HabitLogic.tap(habit, on: now, context: context)
                    }
                }
            }
        }
        .card()
    }

    // MARK: Spent today

    var spentCard: some View {
        let spent = HabitLogic.spentCents(on: .now, entries: entries)
        let work = PayEngine.workSeconds(forCents: spent, rateCents: job.hourlyRateCents, taxBasisPoints: job.taxBasisPoints)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("Spent today")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.money(spent, job.currencyCode))
                        .font(AppFont.num(22, medium: true))
                        .foregroundStyle(spent > 0 ? Theme.coral : Theme.ink)
                    if spent > 0 {
                        Text("= \(Fmt.hm(work, roundToNearest: true)) of work")
                            .font(AppFont.num(12))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            Spacer()
            Button { showAddExpense = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.onInk)
                    .frame(width: 42, height: 42)
                    .background(Theme.ink, in: Circle())
            }
            .accessibilityLabel("Add expense")
        }
        .card()
    }
}

// MARK: - Punch card

struct PunchCard: View {
    let job: Job
    var onPunchOut: (Shift) -> Void
    @Environment(\.modelContext) var context

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(now: timeline.date)
        }
    }

    @ViewBuilder
    func content(now: Date) -> some View {
        let shift = job.runningShift
        let onBreak = shift?.runningBreak != nil
        let live = shift.flatMap { PayPeriods.liveResult(for: $0, job: job, now: now) }
        let today = todayTotals(now: now)

        VStack(spacing: 14) {
            PunchRing(mode: shift == nil ? .off : (onBreak ? .onBreak : .onShift),
                      stateText: stateText(shift: shift, now: now),
                      seconds: live?.workedSeconds ?? today.seconds,
                      money: Fmt.money(live?.grossCents ?? today.cents, job.currencyCode),
                      caption: shift == nil ? "earned today" : "earned so far")

            if let live, live.overtimeSeconds > 0 {
                Chip(text: "Overtime \(Fmt.hm(live.overtimeSeconds))", symbol: "bolt.fill", style: .amber)
            }

            Text(metaText(shift: shift))
                .font(AppFont.num(12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            if let shift {
                HStack(spacing: 10) {
                    Button {
                        if onBreak {
                            ShiftActions.endBreak(shift, context: context)
                        } else {
                            ShiftActions.startBreak(shift, job: job, context: context)
                        }
                        Haptics.tap()
                    } label: {
                        Label(onBreak ? "End break" : "Start break", systemImage: "cup.and.saucer")
                    }
                    .buttonStyle(.pillSoft)

                    Button {
                        ShiftActions.punchOut(shift, context: context)
                        Haptics.success()
                        onPunchOut(shift)
                    } label: {
                        Label("Punch out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.pillInk)
                }
            } else {
                Button {
                    ShiftActions.punchIn(job: job, context: context)
                    Haptics.success()
                } label: {
                    Label("Punch in", systemImage: "clock.badge.checkmark")
                }
                .buttonStyle(.pillGreen)
            }
        }
        .card(padding: 16)
    }

    func stateText(shift: Shift?, now: Date) -> String {
        guard let shift else { return "NOT ON SHIFT" }
        if let b = shift.runningBreak {
            return "ON BREAK · " + Fmt.hm(Int(now.timeIntervalSince(b.start)))
        }
        return "ON SHIFT"
    }

    func metaText(shift: Shift?) -> String {
        let rate = Fmt.money(job.hourlyRateCents, job.currencyCode) + "/hr"
        if let shift {
            return "In at \(Fmt.time(shift.start)) · \(rate) · \(job.name)"
        }
        return "\(job.name) · \(rate)"
    }

    /// Finished shifts that started today.
    func todayTotals(now: Date) -> (seconds: Int, cents: Int) {
        let todays = job.shifts.filter { !$0.isRunning && Calendar.current.isDate($0.start, inSameDayAs: now) }
        guard !todays.isEmpty else { return (0, 0) }
        let results = PayPeriods.results(for: job, now: now)
        let pays = todays.compactMap { results[$0.uid] }
        return (pays.reduce(0) { $0 + $1.workedSeconds }, pays.reduce(0) { $0 + $1.grossCents })
    }
}

struct PunchRing: View {
    enum Mode { case off, onShift, onBreak }
    let mode: Mode
    let stateText: String
    let seconds: Int
    let money: String
    let caption: String

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var spin = false

    var tint: Color {
        switch mode {
        case .off: return Theme.line
        case .onShift: return Theme.green
        case .onBreak: return Theme.amber
        }
    }

    var face: Color {
        switch mode {
        case .off: return Theme.sunk
        case .onShift: return Theme.greenSoft
        case .onBreak: return Theme.amberSoft
        }
    }

    var labelColor: Color {
        switch mode {
        case .off: return Theme.muted
        case .onShift: return Theme.green
        case .onBreak: return Theme.amber
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [2, 7.6]))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(spinAnimation, value: spin)
            Circle()
                .fill(face)
                .padding(12)
            VStack(spacing: 2) {
                Text(stateText)
                    .font(AppFont.text(11, .bold, relativeTo: .caption))
                    .tracking(1.2)
                    .foregroundStyle(labelColor)
                Text(Fmt.clock(seconds))
                    .font(AppFont.num(34, medium: true))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(money)
                    .font(AppFont.num(20, medium: true))
                    .foregroundStyle(mode == .off ? Theme.ink : Theme.green)
                Text(caption)
                    .font(AppFont.text(12))
                    .foregroundStyle(Theme.muted)
            }
            .minimumScaleFactor(0.7)
            .padding(24)
        }
        .frame(width: 210, height: 210)
        .accessibilityElement(children: .combine)
        .onAppear { spin = mode == .onShift && !reduceMotion }
        .onChange(of: mode) { _, newMode in
            spin = newMode == .onShift && !reduceMotion
        }
    }

    var spinAnimation: Animation? {
        spin ? Animation.linear(duration: 40).repeatForever(autoreverses: false) : nil
    }
}

// MARK: - Shift summary after punch out

struct ShiftSummarySheet: View {
    let shift: Shift
    let job: Job
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @State var tipsText = ""
    @State var note = ""

    var body: some View {
        let result = PayPeriods.results(for: job)[shift.uid]
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Shift saved").font(AppFont.display(28)).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.green)
            }

            TicketCard(fill: Theme.sunk) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(Fmt.time(shift.start)) – \(Fmt.time(shift.end ?? .now))")
                        .font(AppFont.num(15, medium: true))
                        .foregroundStyle(Theme.ink)
                    Perforation()
                    SummaryRow(title: "Worked", value: Fmt.hm(result?.workedSeconds ?? 0))
                    if shift.unpaidBreakSeconds > 0 {
                        SummaryRow(title: "Unpaid breaks", value: Fmt.hm(shift.unpaidBreakSeconds, roundToNearest: true))
                    }
                    if let r = result, r.overtimeSeconds > 0 {
                        SummaryRow(title: "Overtime", value: Fmt.hm(r.overtimeSeconds), color: Theme.amber)
                    }
                    SummaryRow(title: "Pay", value: Fmt.money(result?.grossCents ?? 0, job.currencyCode), color: Theme.green, big: true)
                }
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Tips or bonus").font(AppFont.text(16, .medium))
                    Spacer()
                    Text(Fmt.currencySymbol(job.currencyCode)).foregroundStyle(Theme.muted)
                    TextField("0.00", text: $tipsText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                        .font(AppFont.num(16, medium: true))
                }
                Divider().overlay(Theme.line)
                TextField("Note (optional)", text: $note)
                    .font(AppFont.text(16))
            }
            .card()

            Spacer()

            Button("Done") {
                shift.tipsCents = Fmt.cents(from: tipsText) ?? 0
                shift.note = note
                try? context.save()
                dismiss()
            }
            .buttonStyle(.pillInk)
        }
        .padding(20)
        .background(Theme.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .onAppear {
            tipsText = shift.tipsCents > 0 ? Fmt.plain(shift.tipsCents) : ""
            note = shift.note
        }
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    var color: Color = Theme.ink
    var big = false

    var body: some View {
        HStack {
            Text(title).font(AppFont.text(15)).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).font(AppFont.num(big ? 22 : 15, medium: true)).foregroundStyle(color)
        }
    }
}

// MARK: - Habit chip (Today)

struct HabitChip: View {
    let habit: Habit
    let status: HabitStatus
    let count: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if status.counts {
                    Image(systemName: habit.kind.isAuto ? "bolt.fill" : "checkmark")
                        .font(.system(size: 10, weight: .bold))
                } else if status == .broken {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                Text(label)
            }
            .font(AppFont.text(13, .semibold, relativeTo: .footnote))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!habit.kind.isAuto)
        .accessibilityLabel("\(habit.name), \(status.counts ? "done" : "not done")")
    }

    var label: String {
        habit.kind == .count ? "\(habit.name) \(count)/\(habit.goal)" : habit.name
    }

    var fg: Color {
        switch status {
        case .done, .onTrack: return Theme.green
        case .broken: return Theme.coral
        case .notDone: return Theme.muted
        }
    }

    var bg: Color {
        switch status {
        case .done, .onTrack: return Theme.greenSoft
        case .broken: return Theme.coralSoft
        case .notDone: return Theme.sunk
        }
    }
}

// MARK: - Small helpers

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

/// Wraps chips onto new lines when they don't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
