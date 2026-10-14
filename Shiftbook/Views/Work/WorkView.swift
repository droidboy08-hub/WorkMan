import SwiftUI
import SwiftData

struct WorkView: View {
    let job: Job
    @Environment(\.modelContext) var context
    @Query(sort: \MoneyEntry.date, order: .reverse) var entries: [MoneyEntry]

    /// 0 = current pay period, -1 = the one before, and so on.
    @State var periodOffset = 0
    @State var editing: Shift?
    @State var addingShift = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            page(now: timeline.date)
        }
        .background(Theme.paper.ignoresSafeArea())
        .sheet(item: $editing) { ShiftEditorView(job: job, shift: $0) }
        .sheet(isPresented: $addingShift) { ShiftEditorView(job: job, shift: nil) }
    }

    func period(now: Date) -> DateInterval {
        var interval = PayPeriods.interval(containing: now, job: job)
        if periodOffset != 0 {
            for _ in 0..<abs(periodOffset) {
                interval = PayPeriods.neighbor(of: interval, direction: periodOffset < 0 ? -1 : 1, job: job)
            }
        }
        return interval
    }

    func page(now: Date) -> some View {
        let interval = period(now: now)
        let results = PayPeriods.results(for: job, now: now)
        let shifts = job.shifts.filter { interval.contains($0.start) }.sorted { $0.start > $1.start }
        let finished = shifts.filter { !$0.isRunning }
        let totals = PayEngine.totals(finished.compactMap { results[$0.uid] }, taxBasisPoints: job.taxBasisPoints)

        return ScrollView {
            VStack(spacing: 14) {
                ScreenHeader(small: job.name, title: "Work") {
                    RoundIconButton(symbol: "plus", label: "Add missed shift") { addingShift = true }
                }
                periodCard(interval: interval, totals: totals)
                if periodOffset == 0 { weekProgress(now: now) }
                shiftList(shifts: shifts, results: results)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: Pay period card

    func periodCard(interval: DateInterval, totals: PayTotals) -> some View {
        let paidNote = "Paycheck \(Fmt.range(interval))"
        let alreadyPaid = entries.contains { $0.kind == .income && $0.note == paidNote }

        return TicketCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { periodOffset -= 1 } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous pay period")
                    Spacer()
                    SectionLabel("Pay period · \(Fmt.range(interval))")
                    Spacer()
                    Button { periodOffset += 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(periodOffset >= 0)
                        .opacity(periodOffset >= 0 ? 0.3 : 1)
                        .accessibilityLabel("Next pay period")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Fmt.money(totals.grossCents, job.currencyCode))
                        .font(AppFont.num(34, medium: true))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.6)
                    Text("≈ \(Fmt.money(totals.takeHomeCents, job.currencyCode)) take-home · \(job.taxBasisPoints / 100)% tax estimate")
                        .font(AppFont.num(12))
                        .foregroundStyle(Theme.muted)
                }

                Perforation()

                VStack(spacing: 6) {
                    PayLine(title: "Regular · \(Fmt.hm(totals.regularSeconds))",
                            value: Fmt.money(totals.regularCents, job.currencyCode), color: Theme.ink)
                    PayLine(title: "Overtime · \(Fmt.hm(totals.overtimeSeconds))",
                            value: Fmt.money(totals.overtimeCents, job.currencyCode),
                            color: totals.overtimeSeconds > 0 ? Theme.amber : Theme.muted)
                    if totals.tipsCents > 0 {
                        PayLine(title: "Tips and bonus", value: Fmt.money(totals.tipsCents, job.currencyCode), color: Theme.ink)
                    }
                }

                if totals.grossCents > 0 {
                    if alreadyPaid {
                        Chip(text: "Paycheck added to Money", symbol: "checkmark", style: .green)
                    } else {
                        Button("Paycheck received · add to Money") {
                            let entry = MoneyEntry(kind: .income, amountCents: totals.takeHomeCents,
                                                   date: .now, category: .pay, note: paidNote)
                            context.insert(entry)
                            try? context.save()
                        }
                        .font(AppFont.text(14, .semibold))
                        .foregroundStyle(Theme.green)
                    }
                }
            }
        }
    }

    // MARK: This week

    func weekProgress(now: Date) -> some View {
        let worked = PayPeriods.weekRegularSeconds(job: job, now: now)
        let limit = job.overtimeThresholdHours * 3600
        let fraction = limit > 0 ? min(1, Double(worked) / Double(limit)) : 0
        let over = max(0, worked - limit)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.overtimeEnabled ? "This week, before overtime" : "This week")
                    .font(AppFont.text(13))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(Fmt.hm(worked)) / \(job.overtimeThresholdHours)h")
                    .font(AppFont.num(13))
                    .foregroundStyle(Theme.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.sunk)
                    Capsule().fill(over > 0 && job.overtimeEnabled ? Theme.amber : Theme.green)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 7)
            if over > 0 && job.overtimeEnabled {
                Text("Overtime this week: \(Fmt.hm(over))")
                    .font(AppFont.num(12))
                    .foregroundStyle(Theme.amber)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Shifts

    @ViewBuilder
    func shiftList(shifts: [Shift], results: [String: ShiftPay]) -> some View {
        if shifts.isEmpty {
            VStack(spacing: 6) {
                Text("No shifts in this pay period")
                    .font(AppFont.text(15, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Punch in on the Today tab, or tap + to add a shift you forgot to punch.")
                    .font(AppFont.text(14))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Shifts")
                ForEach(shifts) { shift in
                    ShiftRow(shift: shift, result: results[shift.uid], currency: job.currencyCode)
                        .onTapGesture { if !shift.isRunning { editing = shift } }
                        .contextMenu {
                            if !shift.isRunning {
                                Button("Edit") { editing = shift }
                                Button("Delete shift", role: .destructive) {
                                    job.shifts.removeAll { $0 === shift }
                                    context.delete(shift)
                                    try? context.save()
                                }
                            }
                        }
                }
            }
        }
    }
}

struct PayLine: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(title).font(AppFont.text(14)).foregroundStyle(color)
            Spacer()
            Text(value).font(AppFont.num(14, medium: true)).foregroundStyle(color)
        }
    }
}

struct ShiftRow: View {
    let shift: Shift
    let result: ShiftPay?
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            DateBlock(date: shift.start, highlighted: shift.isRunning)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Fmt.time(shift.start)) – \(shift.end.map(Fmt.time) ?? "now")")
                    .font(AppFont.num(13, medium: true))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 5) {
                    if shift.isRunning {
                        Text("On shift").font(AppFont.text(12, .semibold)).foregroundStyle(Theme.green)
                    } else if shift.unpaidBreakSeconds > 0 {
                        Text("\(Fmt.hm(shift.unpaidBreakSeconds, roundToNearest: true)) break")
                            .font(AppFont.text(12)).foregroundStyle(Theme.muted)
                    }
                    if let r = result, r.overtimeSeconds > 0 {
                        Chip(text: "\(Fmt.hm(r.overtimeSeconds)) OT", style: .amber)
                    }
                    if shift.tipsCents > 0 {
                        Chip(text: "+ tips", style: .green)
                    }
                    if shift.edited {
                        Chip(text: "Edited", style: .plain)
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.money(result?.grossCents ?? 0, currency))
                    .font(AppFont.num(14, medium: true))
                    .foregroundStyle(shift.isRunning ? Theme.green : Theme.ink)
                Text(Fmt.hm(result?.workedSeconds ?? 0))
                    .font(AppFont.num(12))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(8)
        .padding(.trailing, 6)
        .background(shift.isRunning ? Theme.greenSoft : Theme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .contentShape(Rectangle())
    }
}
