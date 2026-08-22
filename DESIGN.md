# Svátek dnes – design brief

Czech-only iOS app (iOS 17+) showing namedays (jmeniny) and Czech public
holidays, matching them against the user's contacts.

## Visual language

- **Minimalistic** (explicit owner requirement): restrained, native-first
  UI. Few colors (green accent + system neutrals + red only for days off),
  generous whitespace, no decorative ornaments, no shadows beyond system
  defaults, at most one gradient surface per screen (the hero card).
  When in doubt, remove.
- **Accent**: dark green. Use `Color.accentColor` for interactive elements
  and `Color.brandGreen` (asset, adapts light/dark) for brand surfaces.
  Hero surfaces may use `LinearGradient` of `Color.brandGreen` and
  `Color.brandGreen.opacity(0.75)`.
- **Backgrounds**: always system (`Color(.systemBackground)`,
  `Color(.systemGroupedBackground)`) so light/dark mode works. Never
  hardcode white/black backgrounds.
- Text on brand-green surfaces is white (`.foregroundStyle(.white)`);
  secondary text there uses `.white.opacity(0.85)`.
- Native SwiftUI components: `List`, `NavigationStack`, SF Symbols.
  Rounded, friendly: `.fontDesign(.rounded)` for large display names.
- Day-off holidays get a red-ish badge (`.red` – Czech calendars print
  holidays in red); significant days (no day off) get green badges.

## Czech copy rules (IMPORTANT)

- All UI strings are Czech.
- Czech typography uses the **en dash** `–` (U+2013), NEVER the em dash
  `—` (U+2014). Parenthetical dash is spaced: `slovo – slovo`.
  Ranges: `1. 8. – 30. 8.`.
- Date format: `22. 8.` (spaces after dots), `pátek 22. srpna` – use the
  `CzechFormat` helpers, do not hand-roll formatters.
- Names joined the Czech way via `[String].joinedCzech`:
  "Petr a Pavel", "Rut, Matylda a Vlastibor".
- Vocabulary: nameday = "svátek"/"jmeniny"; "Dnes má svátek Karina";
  plural "Dnes mají svátek Petr a Pavel"; holiday kinds:
  "státní svátek", "den pracovního klidu", "významný den".

## Key shared APIs (read the files in Shared/ for full signatures)

- `NamedayStore.shared`: `.entry(month:day:)`, `.entry(for: Date)`,
  `.month(_:)`, `.search(_:)`, `.nextDate(month:day:onOrAfter:)`
- `HolidayCalendar`: `.holidays(year:)`, `.holidays(for: Date)`,
  `.nextDayOff(after:)`
- `CalendarComposer`: `.info(for: Date) -> DayInfo`, `.upcoming(days:from:)`
- `DayInfo`: `.entry`, `.holidays`, `.isDayOff`, `.primaryHoliday`
- `NamedayEntry`: `.names` (canonical), `.alt` (variants), `.displayText`,
  `.variantsText`
- `ContactsService.shared` (app only, `@EnvironmentObject`): `.matched`,
  `.matches(month:day:)`, `.upcoming(from:)`, `.requestAccessAndLoad()`,
  `.isAuthorized`, `.canRequestAccess`, `.status`
- `AppSettings.shared` (app only, `@EnvironmentObject`): notification
  toggles + time
- `CalendarExporter.shared.addAllDayEvent(title:date:yearly:notes:)`
  (throws, async)
- `SnapshotStore.load()` + `WidgetSnapshot.contacts(month:day:)`
  (widget: contact names per day)
- `CzechFormat`: Czech date strings (`fullDate`, `weekdayDayMonth`,
  `dayMonth`, `shortDate(month:day:)`, `monthName`, `relativeDay`)

## Tab structure (RootView, already wired)

1. **Dnes** – hero card for today + upcoming days preview
2. **Kalendář** – browse the whole year by month + search names
3. **Lidé** – contacts with upcoming namedays
4. **Nastavení** – notifications, data update, about
