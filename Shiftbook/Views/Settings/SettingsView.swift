import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var job: Job
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context

    @State var rateText = ""
    @State var confirmReset = false
    @AppStorage("resetRequested") var resetRequested = false

    init(job: Job) {
        self.job = job
    }

    static let weekdays = [1, 2, 3, 4, 5, 6, 7]
    static let roundingOptions = [0, 5, 6, 15]
    static let currencies = ["USD", "INR", "CAD", "GBP", "EUR", "AUD"]

    func weekdayName(_ day: Int) -> String {
        let names = Calendar.current.weekdaySymbols
        return names.indices.contains(day - 1) ? names[day - 1] : "\(day)"
    }

    func roundingName(_ minutes: Int) -> String {
        minutes == 0 ? "Exact minute" : "Nearest \(minutes) min"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Job name", text: $job.name)
                    HStack {
                        Text("Pay per hour")
                        Spacer()
                        Text(Fmt.currencySymbol(job.currencyCode)).foregroundStyle(Theme.muted)
                        TextField("0.00", text: $rateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                            .onChange(of: rateText) { _, text in
                                if let cents = Fmt.cents(from: text), cents > 0 { job.hourlyRateCents = cents }
                            }
                    }
                    Picker("Currency", selection: $job.currencyCode) {
                        ForEach(Self.currencies, id: \.self) { Text($0).tag($0) }
                    }
                } header: {
                    Text("Job")
                } footer: {
                    Text("A new pay rate is used for new shifts. Old shifts keep the rate they were worked at.")
                }

                Section("Pay period") {
                    Picker("Pay period", selection: Binding(get: { job.payPeriod }, set: { job.payPeriod = $0 })) {
                        ForEach(PayPeriodKind.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Week starts on", selection: $job.weekStartsOn) {
                        ForEach(Self.weekdays, id: \.self) { Text(weekdayName($0)).tag($0) }
                    }
                }

                Section {
                    Toggle("Overtime", isOn: $job.overtimeEnabled)
                        .tint(Theme.green)
                    if job.overtimeEnabled {
                        Stepper("After \(job.overtimeThresholdHours) hours a week",
                                value: $job.overtimeThresholdHours, in: 1...80)
                        Picker("Overtime pay", selection: $job.overtimeMultiplierPercent) {
                            Text("1.5×").tag(150)
                            Text("2×").tag(200)
                        }
                    }
                } header: {
                    Text("Overtime")
                }

                Section {
                    Toggle("Breaks are paid", isOn: $job.breaksPaid)
                        .tint(Theme.green)
                    Picker("Rounding", selection: $job.roundingMinutes) {
                        ForEach(Self.roundingOptions, id: \.self) { Text(roundingName($0)).tag($0) }
                    }
                    Stepper("Tax estimate: \(job.taxBasisPoints / 100)%",
                            value: Binding(get: { job.taxBasisPoints / 100 }, set: { job.taxBasisPoints = $0 * 100 }),
                            in: 0...50)
                } header: {
                    Text("Breaks, rounding and tax")
                } footer: {
                    Text("Only turn on rounding if your employer rounds punch times. Tax is only an estimate, to show take-home pay.")
                }

                Section {
                    Button("Delete everything and start over", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Shiftbook \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · All data stays on this phone.")
                }
            }
            .font(AppFont.text(16))
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
            .confirmationDialog("Delete everything?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    // The app switches back to the welcome screen first, then deletes (see RootView).
                    resetRequested = true
                }
            } message: {
                Text("All shifts, money and habits on this phone will be deleted. This can't be undone.")
            }
            .onAppear { rateText = Fmt.plain(job.hourlyRateCents) }
        }
        .tint(Theme.ink)
    }
}
