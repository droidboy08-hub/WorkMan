# WorkMan — notes for Claude Code

App name: **WorkMan** (renamed from the working name "Shiftbook" on Oct 14, 2026). A habit, money and pay tracker for hourly workers (iPhone first, Android later).
Owner: Pankaj. He does not write code himself. Explain things in simple English (it is not his first language),
give step-by-step instructions, and keep replies short. Do not switch to Hindi.

Full plan (source of truth for features): Notion page "WorkMan — Habit, Money & Pay Tracker (Project Plan)"
and the Claude doc https://claude.ai/code/artifact/0081e2ff-2ef1-4258-95d5-f103c030096d
Design mockups: `docs/design.html` (also https://claude.ai/artifact/NxwXa2mzch8uppEmLyFgLC).

## Status (Oct 14, 2026)
- First demo of **Phase 1** is written: onboarding, Today (punch in/out, breaks, live timer and pay),
  Work (pay periods, overtime, shift list, add/edit/delete shift), Money (quick add, month summary,
  category bar, cost in work hours), Habits (yes/no, count, automatic money habits, streaks), Settings.
- The code was written on Linux **without a Swift compiler**. A separate review found no compile errors,
  but it has never been built. First job in Claude Code: build it, fix any errors, run the tests (⌘U).
- The pay math was cross-checked in Python against every test case and all matched.

## Tech
- SwiftUI + SwiftData, iOS 17+, iPhone only, Swift 5 language mode (`SWIFT_VERSION = 5.0`).
- Xcode project uses file-system synchronized folders (objectVersion 77, needs Xcode 16+):
  every file in `WorkMan/` is in the app target, every file in `WorkManTests/` is in the test target.
  Do not add files to the project by hand; just put them in the folder.
- `Info.plist` at the project root only holds `UIAppFonts`. Everything else is generated from build settings.
- Bundle ID `com.droidboy.workman`. `DEVELOPMENT_TEAM` is empty: pick a team in Signing & Capabilities
  to run on a real iPhone.
- Tests use Swift Testing (`import Testing`), in `WorkManTests/PayEngineTests.swift`.

## Layout
- `WorkMan/Pay/PayEngine.swift` — pure pay math, no UI. All money in whole **cents** (Int).
  Exact pay kept as "units" (seconds × rate cents × multiplier %) and rounded to cents once, at the end.
  Worked time = real elapsed time (safe across daylight saving). Overtime is per work week; extra hours
  go to the latest shifts of the week. Each shift stores its own rate, so a raise never changes old shifts.
- `WorkMan/Models/Models.swift` — SwiftData models: Job, Shift, BreakPeriod, MoneyEntry, Habit, HabitCheck.
  Enums are stored as raw strings. `Shift.end == nil` means the user is punched in.
- `WorkMan/Logic/` — ShiftActions (punch in/out, breaks), PayPeriods, HabitLogic, Formatters (`Fmt`), SampleData.
- `WorkMan/Theme/` — "Time Card" design language: colors (`Theme`), fonts (`AppFont`), shared parts
  (TicketCard with punched notches, Perforation, Chip, pill button styles).
- `WorkMan/Views/` — Onboarding, Today, Work, Money, Habits, Settings.

## Rules to keep
- Green = money earned / on shift. Coral = money spent. Amber = overtime, breaks, streaks. Ink = main buttons.
- Fonts: Bricolage Grotesque (titles), Figtree (text), DM Mono (every time and money amount).
- Every color has a light and a dark version.
- Change SwiftData relationships on the **parent's list** (`job.shifts.append`, `shift.breaks.append`,
  `habit.checks.append` / `removeAll`) so screens refresh at once on iOS 17.
- When deleting a model that a sheet is showing, close the sheet first, then delete.
- Reminders must **always ask**; the app never punches in or out by itself.
- Data stays on the phone. No accounts, no analytics.

## Next steps (Phase 2, see plan)
Lock-screen Live Activity + widget, paycheck check, shift schedule + punch-in reminders + late tracking,
recurring expenses, budgets, several jobs, CSV/PDF export. Phase 3: Android (Kotlin), location check-in.
