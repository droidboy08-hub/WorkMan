import SwiftUI
import SwiftData

/// Quick add: amount → category → done.
struct AddEntrySheet: View {
    let job: Job
    let startKind: EntryKind
    let existing: MoneyEntry?

    init(job: Job, startKind: EntryKind, existing: MoneyEntry? = nil) {
        self.job = job
        self.startKind = startKind
        self.existing = existing
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context

    @State var kind: EntryKind = .expense
    @State var amountText = ""
    @State var category: MoneyCategory = .food
    @State var note = ""
    @State var date = Date.now
    @State var loaded = false
    @FocusState var amountFocused: Bool

    var cents: Int { Fmt.cents(from: amountText) ?? 0 }
    var canSave: Bool { cents > 0 && category.kind == kind }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Type", selection: $kind) {
                        ForEach(EntryKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newKind in
                        if category.kind != newKind { category = MoneyCategory.all(for: newKind)[0] }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(Fmt.currencySymbol(job.currencyCode))
                                .font(AppFont.num(30, medium: true))
                                .foregroundStyle(Theme.muted)
                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(AppFont.num(44, medium: true))
                                .foregroundStyle(kind == .expense ? Theme.coral : Theme.green)
                                .focused($amountFocused)
                        }
                        if kind == .expense && cents > 0 {
                            let work = PayEngine.workSeconds(forCents: cents, rateCents: job.hourlyRateCents,
                                                             taxBasisPoints: job.taxBasisPoints)
                            Text("= \(Fmt.hm(work, roundToNearest: true)) of work")
                                .font(AppFont.num(14))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Category")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(MoneyCategory.all(for: kind)) { c in
                                CategoryButton(category: c, selected: c == category) { category = c }
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        TextField("Note, like \"Groceries\"", text: $note)
                            .font(AppFont.text(16))
                            .padding(.vertical, 12)
                        Divider().overlay(Theme.line)
                        DatePicker("Date", selection: $date, displayedComponents: [.date])
                            .font(AppFont.text(16))
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if existing != nil {
                        Button("Delete", role: .destructive) {
                            if let existing { context.delete(existing) }
                            try? context.save()
                            dismiss()
                        }
                        .font(AppFont.text(15, .semibold))
                        .foregroundStyle(Theme.coral)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle(existing == nil ? "Add" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave).bold()
                }
            }
            .onAppear(perform: load)
        }
        .tint(Theme.ink)
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            kind = existing.kind
            amountText = Fmt.plain(existing.amountCents)
            category = existing.category
            note = existing.note
            date = existing.date
        } else {
            kind = startKind
            category = MoneyCategory.all(for: startKind)[0]
            amountFocused = true
        }
    }

    func save() {
        if let existing {
            existing.kindRaw = kind.rawValue
            existing.amountCents = cents
            existing.categoryRaw = category.rawValue
            existing.note = note
            existing.date = date
        } else {
            // Keep the current time of day when the date is today, so lists stay in order.
            let cal = Calendar.current
            let when = cal.isDateInToday(date) ? Date.now : date
            context.insert(MoneyEntry(kind: kind, amountCents: cents, date: when, category: category, note: note))
        }
        try? context.save()
        dismiss()
    }
}

struct CategoryButton: View {
    let category: MoneyCategory
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onInk : category.color)
                Text(category.title)
                    .font(AppFont.text(12, .semibold))
                    .foregroundStyle(selected ? Theme.onInk : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? Theme.ink : Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
