import SwiftUI
import SwiftData

struct HabitsView: View {
    let job: Job
    @Environment(\.modelContext) var context
    @Query(sort: \Habit.order) var habits: [Habit]
    @Query(sort: \MoneyEntry.date, order: .reverse) var entries: [MoneyEntry]
    @State var adding = false

    var body: some View {
        let now = Date.now
        let done = habits.filter { HabitLogic.status($0, on: now, entries: entries, now: now).counts }.count

        ScrollView {
            VStack(spacing: 14) {
                ScreenHeader(small: habits.isEmpty ? "No habits yet" : "\(done) of \(habits.count) done today",
                             title: "Habits") {
                    RoundIconButton(symbol: "plus", label: "Add habit") { adding = true }
                }
                weekStrip(now: now)
                if habits.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 8) {
                        ForEach(habits) { habit in
                            HabitRow(habit: habit,
                                     status: HabitLogic.status(habit, on: now, entries: entries, now: now),
                                     count: HabitLogic.count(habit, on: now),
                                     streak: HabitLogic.streak(habit, entries: entries, now: now),
                                     detail: detail(for: habit, now: now)) {
                                HabitLogic.tap(habit, on: now, context: context)
                            }
                            .contextMenu {
                                Button("Delete habit", role: .destructive) {
                                    context.delete(habit)
                                    try? context.save()
                                }
                            }
                        }
                    }
                    Text("Auto habits check themselves from your spending. Long-press a habit to delete it.")
                        .font(AppFont.text(13))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.paper.ignoresSafeArea())
        .sheet(isPresented: $adding) { AddHabitSheet(job: job, nextOrder: (habits.map(\.order).max() ?? -1) + 1) }
    }

    func weekStrip(now: Date) -> some View {
        let cal = PayPeriods.calendar(for: job)
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }

        return HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let isToday = cal.isDate(day, inSameDayAs: now)
                let isPast = day < cal.startOfDay(for: now)
                let allDone = !habits.isEmpty && habits.allSatisfy {
                    HabitLogic.status($0, on: day, entries: entries, now: now).counts
                }
                VStack(spacing: 4) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(AppFont.text(11, .semibold))
                        .foregroundStyle(isToday ? Theme.onInk : Theme.muted)
                    Text(day.formatted(.dateTime.day()))
                        .font(AppFont.num(15, medium: true))
                        .foregroundStyle(isToday ? Theme.onInk : Theme.ink)
                    Circle()
                        .fill((isPast || isToday) && allDone ? (isToday ? Theme.onInk : Theme.green) : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isToday ? Theme.ink : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week. A dot means every habit was done that day.")
    }

    func detail(for habit: Habit, now: Date) -> String {
        switch habit.kind {
        case .foodUnder:
            let food = HabitLogic.spentCents(on: now, entries: entries, category: .food)
            return "\(Fmt.money(food, job.currencyCode)) on food so far"
        case .noSpend:
            let spent = HabitLogic.spentCents(on: now, entries: entries)
            return spent == 0 ? "Nothing spent today" : "\(Fmt.money(spent, job.currencyCode)) spent today"
        default:
            return ""
        }
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Text("Start with one small habit")
                .font(AppFont.text(16, .semibold))
                .foregroundStyle(Theme.ink)
            Text("Tap + to add a habit, like reading 10 pages or keeping food spending under a limit.")
                .font(AppFont.text(14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct HabitRow: View {
    let habit: Habit
    let status: HabitStatus
    let count: Int
    let streak: Int
    let detail: String
    var onTap: () -> Void

    var tint: Color {
        switch habit.kind {
        case .check: return Theme.green
        case .count: return Theme.catBlue
        case .noSpend, .foodUnder: return Theme.coral
        }
    }

    var soft: Color {
        switch habit.kind {
        case .check: return Theme.greenSoft
        case .count: return Theme.sunk
        case .noSpend, .foodUnder: return Theme.coralSoft
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: habit.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(soft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(AppFont.text(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if habit.kind.isAuto {
                        Chip(text: "Auto", symbol: "bolt.fill", style: .green)
                    }
                    if habit.kind == .count {
                        SegmentDots(filled: count, total: max(1, habit.goal))
                    } else if !detail.isEmpty {
                        Text(detail).font(AppFont.num(11)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    if streak > 0 && habit.kind != .count {
                        Label("\(streak)", systemImage: "flame.fill")
                            .font(AppFont.num(11, medium: true))
                            .foregroundStyle(Theme.amber)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            Spacer(minLength: 6)
            control
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    var control: some View {
        switch habit.kind {
        case .check:
            Button(action: onTap) { CheckCircle(on: status == .done) }
                .buttonStyle(.plain)
                .accessibilityLabel(status == .done ? "Done. Tap to undo." : "Mark as done")
        case .count:
            HStack(spacing: 8) {
                Text("\(count)/\(habit.goal)")
                    .font(AppFont.num(13, medium: true))
                    .foregroundStyle(status == .done ? Theme.green : Theme.ink)
                Button(action: onTap) {
                    Image(systemName: status == .done ? "arrow.counterclockwise" : "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.onInk)
                        .frame(width: 32, height: 32)
                        .background(Theme.ink, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(status == .done ? "Start over" : "Add one")
            }
        case .noSpend, .foodUnder:
            if status == .broken {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.coral)
                    .accessibilityLabel("Missed today")
            } else {
                CheckCircle(on: true)
                    .accessibilityLabel("On track")
            }
        }
    }
}

struct CheckCircle: View {
    let on: Bool
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(on ? Theme.green : Theme.line, lineWidth: 2)
                .background(Circle().fill(on ? Theme.green : Color.clear))
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.card)
            }
        }
        .frame(width: 30, height: 30)
    }
}

struct SegmentDots: View {
    let filled: Int
    let total: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(total, 12), id: \.self) { i in
                Capsule()
                    .fill(i < filled ? Theme.green : Theme.line)
                    .frame(width: 10, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Add habit

struct AddHabitSheet: View {
    let job: Job
    let nextOrder: Int
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context

    @State var name = ""
    @State var kind: HabitKind = .check
    @State var goal = 8
    @State var limitText = "20.00"
    @State var symbol = "star"

    static let symbols = ["star", "book", "drop", "figure.walk", "dumbbell", "bed.double", "leaf", "brain.head.profile",
                          "fork.knife", "cup.and.saucer", "phone.down", "banknote"]

    var limitCents: Int { Fmt.cents(from: limitText) ?? 0 }

    var finalName: String {
        let typed = name.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }
        switch kind {
        case .noSpend: return "No-spend day"
        case .foodUnder: return "Food under \(Fmt.money(limitCents, job.currencyCode))"
        default: return ""
        }
    }

    var canSave: Bool {
        !finalName.isEmpty && (kind != .foodUnder || limitCents > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(HabitKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    TextField(kind.isAuto ? "Name (optional)" : "Name, like \"Read 10 pages\"", text: $name)
                    if kind == .count {
                        Stepper("Goal: \(goal) a day", value: $goal, in: 2...30)
                    }
                    if kind == .foodUnder {
                        HStack {
                            Text("Daily food limit")
                            Spacer()
                            Text(Fmt.currencySymbol(job.currencyCode)).foregroundStyle(Theme.muted)
                            TextField("20.00", text: $limitText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 80)
                        }
                    }
                } footer: {
                    if kind.isAuto {
                        Text("Auto habits check themselves from the expenses you add in Money.")
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(Self.symbols, id: \.self) { s in
                            Button { symbol = s } label: {
                                Image(systemName: s)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(symbol == s ? Theme.onInk : Theme.ink)
                                    .frame(width: 40, height: 40)
                                    .background(symbol == s ? Theme.ink : Theme.sunk, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(s)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .font(AppFont.text(16))
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave).bold()
                }
            }
            .onChange(of: kind) { _, newKind in
                if newKind == .foodUnder { symbol = "fork.knife" }
                if newKind == .noSpend { symbol = "banknote" }
            }
        }
        .tint(Theme.ink)
    }

    func save() {
        let habit = Habit(name: finalName,
                          symbol: symbol,
                          kind: kind,
                          goal: kind == .count ? goal : (kind == .foodUnder ? limitCents : 1),
                          order: nextOrder)
        context.insert(habit)
        try? context.save()
        dismiss()
    }
}
