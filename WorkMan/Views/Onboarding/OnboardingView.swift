import SwiftUI
import SwiftData

struct OnboardingView: View {
    @State var step = 0

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if step == 0 {
                WelcomeStep { withAnimation(.easeInOut) { step = 1 } }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                JobSetupStep { withAnimation(.easeInOut) { step = 0 } }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Logo

struct LogoMark: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            TicketShape(notchY: size * 0.63, cornerRadius: size * 0.26, notchRadius: size * 0.08)
                .fill(Theme.ink)
            Circle()
                .stroke(Theme.green, lineWidth: size * 0.05)
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: -size * 0.08)
            Path { p in
                p.move(to: CGPoint(x: size / 2, y: size * 0.30))
                p.addLine(to: CGPoint(x: size / 2, y: size * 0.42))
                p.addLine(to: CGPoint(x: size * 0.58, y: size * 0.47))
            }
            .stroke(Theme.green, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Step 1: Welcome

struct WelcomeStep: View {
    var onStart: () -> Void

    var body: some View {
        ScrollView {
            welcomeContent
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            LogoMark()
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("Every minute,\ncounted.")
                    .font(AppFont.display(44))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Punch in and out. See exactly what you earned, where your money went, and which habits you kept.")
                    .font(AppFont.text(17))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(symbol: "clock", tint: Theme.green, soft: Theme.greenSoft,
                           title: "Exact pay", detail: "Down to the minute, with overtime.")
                FeatureRow(symbol: "wallet.pass", tint: Theme.coral, soft: Theme.coralSoft,
                           title: "Money in, money out", detail: "See every expense in hours of work.")
                FeatureRow(symbol: "checkmark.circle", tint: Theme.amber, soft: Theme.amberSoft,
                           title: "Habits that check themselves", detail: "Like keeping food under a limit.")
            }

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                Capsule().fill(Theme.ink).frame(width: 20, height: 7)
                Circle().fill(Theme.line).frame(width: 7, height: 7)
            }
            .accessibilityHidden(true)

            Button("Get started", action: onStart)
                .buttonStyle(.pillInk)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }
}

struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let soft: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(soft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AppFont.text(16, .semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(AppFont.text(14)).foregroundStyle(Theme.muted)
            }
        }
    }
}

// MARK: - Step 2: Job setup

struct JobSetupStep: View {
    var onBack: () -> Void
    @Environment(\.modelContext) var context

    @State var jobName = "Gas station"
    @State var rateText = "15.00"
    @State var currency = "USD"
    @State var period: PayPeriodKind = .biweekly
    @State var overtime = true
    @State var taxPercent = 12
    @State var addExamples = true

    static let currencies = ["USD", "INR", "CAD", "GBP", "EUR", "AUD"]

    var rateCents: Int { Fmt.cents(from: rateText) ?? 0 }
    var shiftPay: Int { rateCents * 8 }
    var takeHome: Int { shiftPay - (shiftPay * taxPercent + 50) / 100 }
    var canContinue: Bool { rateCents > 0 && !jobName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    RoundIconButton(symbol: "chevron.left", label: "Back", action: onBack)
                    Spacer()
                    SectionLabel("Step 2 of 2")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your job").font(AppFont.display(34)).foregroundStyle(Theme.ink)
                    Text("You can change all of this later in Settings.")
                        .font(AppFont.text(15)).foregroundStyle(Theme.muted)
                }

                VStack(spacing: 0) {
                    SetupRow(title: "Job name") {
                        TextField("Job name", text: $jobName)
                            .multilineTextAlignment(.trailing)
                            .font(AppFont.text(16, .medium))
                    }
                    Divider().overlay(Theme.line)
                    SetupRow(title: "Pay per hour") {
                        HStack(spacing: 4) {
                            Text(Fmt.currencySymbol(currency)).foregroundStyle(Theme.muted)
                            TextField("0.00", text: $rateText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                        }
                        .font(AppFont.num(16, medium: true))
                    }
                    Divider().overlay(Theme.line)
                    SetupRow(title: "Currency") {
                        Picker("Currency", selection: $currency) {
                            ForEach(Self.currencies, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.ink)
                    }
                    Divider().overlay(Theme.line)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pay period").font(AppFont.text(16, .medium)).foregroundStyle(Theme.ink)
                        Picker("Pay period", selection: $period) {
                            ForEach(PayPeriodKind.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 12)
                    Divider().overlay(Theme.line)
                    Toggle(isOn: $overtime) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Overtime").font(AppFont.text(16, .medium)).foregroundStyle(Theme.ink)
                            Text("After 40 h a week · 1.5×").font(AppFont.num(12)).foregroundStyle(Theme.muted)
                        }
                    }
                    .tint(Theme.green)
                    .padding(.vertical, 10)
                    Divider().overlay(Theme.line)
                    Stepper(value: $taxPercent, in: 0...50) {
                        HStack {
                            Text("Tax estimate").font(AppFont.text(16, .medium)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(taxPercent)%").font(AppFont.num(16, medium: true)).foregroundStyle(Theme.ink)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                TicketCard {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("An 8-hour shift")
                        Perforation()
                        HStack(alignment: .firstTextBaseline) {
                            Text(Fmt.money(shiftPay, currency))
                                .font(AppFont.num(28, medium: true))
                                .foregroundStyle(Theme.green)
                            Spacer()
                            Text("≈ \(Fmt.money(takeHome, currency)) take-home")
                                .font(AppFont.num(13))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }

                Toggle(isOn: $addExamples) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add example data").font(AppFont.text(16, .medium)).foregroundStyle(Theme.ink)
                        Text("Past shifts, expenses and habits, so you can try every screen.")
                            .font(AppFont.text(13)).foregroundStyle(Theme.muted)
                    }
                }
                .tint(Theme.green)
                .card()

                Button("Start using WorkMan", action: finish)
                    .buttonStyle(.pillInk)
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    func finish() {
        let job = Job(name: jobName.trimmingCharacters(in: .whitespaces),
                      hourlyRateCents: rateCents,
                      currencyCode: currency,
                      payPeriod: period,
                      overtimeEnabled: overtime,
                      taxBasisPoints: taxPercent * 100,
                      periodAnchor: .now)
        context.insert(job)
        if addExamples {
            SampleData.seed(job: job, context: context)
        }
        try? context.save()
    }
}

struct SetupRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            Text(title).font(AppFont.text(16, .medium)).foregroundStyle(Theme.ink)
            Spacer(minLength: 12)
            content
        }
        .padding(.vertical, 12)
    }
}
