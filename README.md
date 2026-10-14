# WorkMan (demo)

Habit, money and pay tracker. Punch in and out, and the app works out your exact pay.

## Run it on your Mac (5 minutes)

1. In Terminal: `git clone https://github.com/droidboy08-hub/WorkMan.git`
2. Open the `WorkMan` folder and double-click `WorkMan.xcodeproj`. You need Xcode 16 or newer.
3. At the top of Xcode, pick an iPhone simulator, for example "iPhone 17".
4. Press **⌘R** (Run). The app opens on the welcome screen.
5. Tap **Get started**, keep **Add example data** on, and tap **Start using WorkMan**.

## Run the pay tests

Press **⌘U** (Test). There are 12 tests. They check every pay example from the plan:
one shift, overtime, rounding, past midnight, daylight saving, a raise mid-week, and more.
All 12 should show a green check.

## Run it on your own iPhone

1. Plug in the iPhone and pick it at the top of Xcode.
2. Click the blue **WorkMan** project icon, then **Signing & Capabilities**.
3. Under **Team**, pick your Apple developer team.
4. Press **⌘R**.

## If something goes wrong

This first version was written without a Mac, so Xcode may show a few red errors on the first build.
Open the project in Claude Code and say: "Build the app, fix any errors, then run the tests."
The file `CLAUDE.md` tells Claude Code everything about the project.

## What's in this demo

- **Welcome and setup:** job name, pay per hour, currency, pay period, overtime, tax estimate.
- **Today:** big Punch in / Punch out, breaks, live timer and money earned, habits, money spent today.
- **Work:** pay period total, regular and overtime split, every shift, add or fix a shift.
- **Money:** add expenses and income, month summary, spending by category,
  and each expense shown in hours of work.
- **Habits:** yes/no and count habits, automatic money habits, and streaks.
- **Settings:** change pay, overtime, rounding, tax, or delete everything.

Not in this demo yet (Phase 2): lock-screen timer, widget, reminders, location check-in, paycheck check, export.

Fonts: Bricolage Grotesque, Figtree and DM Mono, all under the SIL Open Font License (files in `WorkMan/Resources/Fonts`).
