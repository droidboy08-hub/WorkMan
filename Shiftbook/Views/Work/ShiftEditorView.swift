import SwiftUI
import SwiftData

/// Add a shift you forgot to punch, or fix an existing one.
/// Any change marks the shift "Edited", so the record stays honest.
struct ShiftEditorView: View {
    let job: Job
    /// nil = new shift.
    let shift: Shift?

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context

    @State var start = Date.now
    @State var end = Date.now
    @State var breakMinutes = 30
    @State var tipsText = ""
    @State var note = ""
    @State var confirmDelete = false
    @State var loaded = false
    /// Copied from the shift on load, so the screen never reads a deleted shift.
    @State var rateCents = 0

    var isNew: Bool { shift == nil }
    var isValid: Bool { end > start && end.timeIntervalSince(start) < 24 * 3600 }

    var previewSeconds: Int {
        let breaks = breakMinutes > 0
            ? [PayBreak(start: start, end: start.addingTimeInterval(Double(breakMinutes) * 60), paid: false)]
            : []
        return PayEngine.workedSeconds(start: start, end: end, breaks: breaks,
                                       roundingMinutes: job.roundingMinutes, timeZone: .current)
    }

    var previewCents: Int {
        PayEngine.cents(fromUnits: Int64(previewSeconds) * Int64(rateCents) * 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $start)
                    DatePicker("End", selection: $end)
                    Stepper(value: $breakMinutes, in: 0...240, step: 5) {
                        HStack {
                            Text("Unpaid break")
                            Spacer()
                            Text("\(breakMinutes) min").font(AppFont.num(15)).foregroundStyle(Theme.muted)
                        }
                    }
                } footer: {
                    if !isValid {
                        Text("End time must be after start time, and a shift can't be longer than 24 hours.")
                            .foregroundStyle(Theme.coral)
                    }
                }

                Section {
                    HStack {
                        Text("Tips or bonus")
                        Spacer()
                        Text(Fmt.currencySymbol(job.currencyCode)).foregroundStyle(Theme.muted)
                        TextField("0.00", text: $tipsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                    }
                    TextField("Note (optional)", text: $note)
                }

                Section {
                    HStack {
                        Text("Worked")
                        Spacer()
                        Text(Fmt.hm(previewSeconds)).font(AppFont.num(15, medium: true))
                    }
                    HStack {
                        Text("Pay before overtime")
                        Spacer()
                        Text(Fmt.money(previewCents, job.currencyCode))
                            .font(AppFont.num(15, medium: true))
                            .foregroundStyle(Theme.green)
                    }
                } footer: {
                    Text("Overtime is worked out across the whole week on the Work tab.")
                }

                if !isNew {
                    Section {
                        Button("Delete shift", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .font(AppFont.text(16))
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle(isNew ? "Add shift" : "Edit shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid).bold()
                }
            }
            .confirmationDialog("Delete this shift?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete shift", role: .destructive) {
                    guard let shift else { return }
                    // Close the screen first, then delete, so nothing reads the deleted shift.
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        job.shifts.removeAll { $0 === shift }
                        context.delete(shift)
                        try? context.save()
                    }
                }
            } message: {
                Text("Its hours and pay will be removed from the pay period.")
            }
            .onAppear(perform: load)
        }
        .tint(Theme.ink)
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        rateCents = shift?.rateCents ?? job.hourlyRateCents
        if let shift {
            start = shift.start
            end = shift.end ?? .now
            breakMinutes = Int((Double(shift.unpaidBreakSeconds) / 60).rounded())
            tipsText = shift.tipsCents > 0 ? Fmt.plain(shift.tipsCents) : ""
            note = shift.note
        } else {
            // A sensible default: yesterday 9:00 – 17:30.
            let cal = Calendar.current
            let yesterday = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
            start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: yesterday) ?? .now
            end = cal.date(bySettingHour: 17, minute: 30, second: 0, of: yesterday) ?? .now
        }
    }

    func save() {
        let tips = Fmt.cents(from: tipsText) ?? 0
        if let shift {
            let oldBreakMinutes = Int((Double(shift.unpaidBreakSeconds) / 60).rounded())
            shift.start = start
            shift.end = end
            shift.tipsCents = tips
            shift.note = note
            if breakMinutes != oldBreakMinutes {
                let unpaid = shift.breaks.filter { !$0.paid }
                shift.breaks.removeAll { !$0.paid }
                for b in unpaid { context.delete(b) }
                if breakMinutes > 0 {
                    let mid = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
                    let b = BreakPeriod(start: mid, end: mid.addingTimeInterval(Double(breakMinutes) * 60), paid: false)
                    context.insert(b)
                    shift.breaks.append(b)
                }
            }
            shift.edited = true
            try? context.save()
        } else {
            ShiftActions.addManual(job: job, start: start, end: end, unpaidBreakMinutes: breakMinutes,
                                   tipsCents: tips, note: note, context: context)
        }
        dismiss()
    }
}
