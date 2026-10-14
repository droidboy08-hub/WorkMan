import SwiftUI
import SwiftData

struct MoneyView: View {
    let job: Job
    @Environment(\.modelContext) var context
    @Query(sort: \MoneyEntry.date, order: .reverse) var entries: [MoneyEntry]

    @State var monthOffset = 0
    @State var addingKind: EntryKind?
    @State var editingEntry: MoneyEntry?

    var month: DateInterval {
        let cal = Calendar.current
        let probe = cal.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
        return cal.dateInterval(of: .month, for: probe) ?? DateInterval(start: probe, duration: 86_400 * 30)
    }

    var body: some View {
        let interval = month
        let monthEntries = entries.filter { interval.contains($0.date) }
        let earned = monthEntries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amountCents }
        let spent = monthEntries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }

        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 14) {
                    header(interval: interval)
                    summary(earned: earned, spent: spent)
                    if spent > 0 { categoryCard(entries: monthEntries, spent: spent) }
                    entryList(monthEntries)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            FloatingAddButton(label: "Add expense or income") { addingKind = .expense }
                .padding(20)
        }
        .background(Theme.paper.ignoresSafeArea())
        .sheet(item: $addingKind) { kind in AddEntrySheet(job: job, startKind: kind) }
        .sheet(item: $editingEntry) { entry in AddEntrySheet(job: job, startKind: .expense, existing: entry) }
    }

    func header(interval: DateInterval) -> some View {
        ScreenHeader(small: interval.start.formatted(.dateTime.month(.wide).year()), title: "Money") {
            HStack(spacing: 8) {
                RoundIconButton(symbol: "chevron.left", label: "Previous month") { monthOffset -= 1 }
                RoundIconButton(symbol: "chevron.right", label: "Next month") { monthOffset += 1 }
                    .disabled(monthOffset >= 0)
                    .opacity(monthOffset >= 0 ? 0.35 : 1)
            }
        }
    }

    func summary(earned: Int, spent: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            SummaryColumn(label: "Earned", value: Fmt.money(earned, job.currencyCode), color: Theme.green)
            SummaryColumn(label: "Spent", value: Fmt.money(spent, job.currencyCode), color: Theme.coral)
            SummaryColumn(label: "Left", value: Fmt.money(earned - spent, job.currencyCode),
                          color: earned - spent < 0 ? Theme.coral : Theme.ink)
        }
        .card()
    }

    func categoryCard(entries: [MoneyEntry], spent: Int) -> some View {
        let byCategory = Dictionary(grouping: entries.filter { $0.kind == .expense }) { $0.category }
            .map { CategoryTotal(category: $0.key, cents: $0.value.reduce(0) { $0 + $1.amountCents }) }
            .sorted { $0.cents > $1.cents }
        let top = byCategory.first
        let topWork = top.map {
            PayEngine.workSeconds(forCents: $0.cents, rateCents: job.hourlyRateCents, taxBasisPoints: job.taxBasisPoints)
        } ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Spent by category")
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(byCategory) { item in
                        Rectangle()
                            .fill(item.category.color)
                            .frame(width: max(2, (geo.size.width - CGFloat(byCategory.count - 1) * 2) * CGFloat(item.cents) / CGFloat(spent)))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .accessibilityHidden(true)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                ForEach(byCategory) { item in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(item.category.color).frame(width: 8, height: 8)
                        Text(item.category.title).font(AppFont.text(13))
                        Spacer(minLength: 4)
                        Text(Fmt.money(item.cents, job.currencyCode)).font(AppFont.num(12, medium: true))
                    }
                    .foregroundStyle(Theme.ink)
                }
            }

            if let top {
                Perforation()
                Text("\(top.category.title) this month = **\(Fmt.hm(topWork, roundToNearest: true))** of work")
                    .font(AppFont.text(13))
                    .foregroundStyle(Theme.muted)
            }
        }
        .card()
        .coordinateSpace(.named("ticket"))
    }

    @ViewBuilder
    func entryList(_ monthEntries: [MoneyEntry]) -> some View {
        if monthEntries.isEmpty {
            VStack(spacing: 6) {
                Text("Nothing this month yet")
                    .font(AppFont.text(15, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Tap + to add an expense or income. Paychecks can be added from the Work tab.")
                    .font(AppFont.text(14))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            let days = Dictionary(grouping: monthEntries) { Calendar.current.startOfDay(for: $0.date) }
                .map { DayGroup(day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
                .sorted { $0.day > $1.day }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(days) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(dayTitle(group.day))
                        VStack(spacing: 0) {
                            ForEach(group.items) { entry in
                                EntryRow(entry: entry, job: job)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingEntry = entry }
                                    .contextMenu {
                                        Button("Edit") { editingEntry = entry }
                                        Button("Delete", role: .destructive) {
                                            context.delete(entry)
                                            try? context.save()
                                        }
                                    }
                                if entry.id != group.items.last?.id {
                                    Divider().overlay(Theme.line)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

struct CategoryTotal: Identifiable {
    let category: MoneyCategory
    let cents: Int
    var id: MoneyCategory { category }
}

struct DayGroup: Identifiable {
    let day: Date
    let items: [MoneyEntry]
    var id: Date { day }
}

struct SummaryColumn: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(label)
            Text(value)
                .font(AppFont.num(16, medium: true))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EntryRow: View {
    let entry: MoneyEntry
    let job: Job

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(entry.category.color)
                .frame(width: 36, height: 36)
                .background(Theme.sunk, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(AppFont.text(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(entry.category.title)
                    .font(AppFont.text(12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text((entry.kind == .expense ? "−" : "+") + Fmt.money(entry.amountCents, job.currencyCode))
                    .font(AppFont.num(14, medium: true))
                    .foregroundStyle(entry.kind == .expense ? Theme.coral : Theme.green)
                if entry.kind == .expense {
                    let work = PayEngine.workSeconds(forCents: entry.amountCents, rateCents: job.hourlyRateCents,
                                                     taxBasisPoints: job.taxBasisPoints)
                    Text("\(Fmt.hm(work, roundToNearest: true)) of work")
                        .font(AppFont.num(11))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.vertical, 10)
    }
}
