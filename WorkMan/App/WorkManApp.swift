import SwiftUI
import SwiftData

@main
struct WorkManApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Job.self, Shift.self, BreakPeriod.self, MoneyEntry.self, Habit.self, HabitCheck.self])
    }
}

/// Shows the welcome flow until a job exists, then the four tabs.
struct RootView: View {
    @Query(sort: \Job.createdAt) var jobs: [Job]
    @Environment(\.modelContext) var context
    /// Set by Settings › Delete everything. The screens close first, then the data is deleted,
    /// so no screen is still showing data that no longer exists.
    @AppStorage("resetRequested") var resetRequested = false

    var body: some View {
        Group {
            if !resetRequested, let job = jobs.first {
                MainTabView(job: job)
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: jobs.isEmpty)
        .onAppear { if resetRequested { resetNow() } }
        .onChange(of: resetRequested) { _, requested in
            guard requested else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { resetNow() }
        }
    }

    func resetNow() {
        SampleData.deleteAll(context: context)
        resetRequested = false
    }
}

struct MainTabView: View {
    let job: Job

    var body: some View {
        TabView {
            TodayView(job: job)
                .tabItem { Label("Today", systemImage: "clock") }
            WorkView(job: job)
                .tabItem { Label("Work", systemImage: "briefcase") }
            MoneyView(job: job)
                .tabItem { Label("Money", systemImage: "wallet.pass") }
            HabitsView(job: job)
                .tabItem { Label("Habits", systemImage: "checkmark.circle") }
        }
        .tint(Theme.ink)
    }
}
