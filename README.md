# Svátek dnes

Czech nameday & holiday app for iOS – shows who has their nameday (jmeniny)
today, upcoming Czech public holidays, and matches namedays against the
user's contacts. Localized UI (Czech, English, German), iOS 17+, SwiftUI.

## Features

- **Namedays (jmeniny)** – the full Czech civil nameday calendar, including
  spelling variants and foreign forms (e.g. *Edita* / *Edyta*) used for
  matching.
- **Czech public holidays** – all fixed state holidays and significant days,
  plus movable feasts (Velký pátek, Velikonoční pondělí, Den matek) computed
  from the Gregorian Easter computus.
- **Contact matching** – contacts whose given name (or nickname) matches a
  calendar name are surfaced on their day. Matching is diacritic-insensitive
  and runs entirely on-device.
- **Local notifications** – optional morning reminder for today's namedays
  and holidays, plus reminders for matched contacts.
- **Widgets** – home-screen and lock-screen widgets showing today's nameday
  and the next holiday.
- **Add to calendar** – one-tap export of a nameday or holiday as an all-day
  (optionally yearly recurring) event via EventKit.
- **Monthly remote data refresh** – holiday data can be corrected remotely
  without an App Store release (see below).

## Architecture

Four targets, generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen):

| Target | Purpose |
| --- | --- |
| `SvatekDnes` | The app (SwiftUI, `App/`, `Views/`, `Services/`) |
| `SvatekWidget` | WidgetKit extension (home/lock-screen widgets) |
| `SvatekWatch` | watchOS app, embedded in the iOS app (`SvatekWatch/`) |
| `SvatekDnesTests` | Unit tests (`Tests/`) |

The app, the widget and the watch app all compile the `Shared/` core:
models, `NamedayStore`, `HolidayCalendar` + `EasterCalculator`,
`CalendarComposer`, `NameMatching`, `AppFormat`/design system, and the
app-group plumbing (`AppGroup`, `WidgetSnapshot`). Keeping `Shared/` on
Foundation, Combine and SwiftUI only – no UIKit, WidgetKit, Contacts or
EventKit – is what lets it compile for watchOS unchanged. Check it with:

```sh
xcrun --sdk watchos swiftc -typecheck -target arm64_32-apple-watchos10.0 \
	-sdk "$(xcrun --sdk watchos --show-sdk-path)" Shared/*.swift
```

### Data flow

1. **Bundled baseline** – `Shared/Resources/namedays.json` ships in the app
   bundle; fixed holidays and the Easter computus are compiled in
   (`HolidayCalendar`, `EasterCalculator`).
2. **Remote overrides** – `data/svatky.json` from this repository is served
   via `raw.githubusercontent.com` (URL in `Shared/AppGroup.swift`). When
   present, it replaces the fixed holiday list, the movable feasts for the
   listed years, and individual nameday entries (`namedayOverrides`).
3. **Refresh cycle** – a `BGAppRefreshTask` runs roughly weekly;
   `HolidayUpdateService` re-downloads the file once the stored copy is
   older than **30 days** (failed attempts retry at most once a day). The
   downloaded file is stored in the app group container so the widget sees
   the same data.

### The watch app

App group containers do not span devices, so the watch shares no storage
with the phone. It is deliberately **not** a mirror: the nameday calendar,
the holidays and the Easter computus are bundled, so today's nameday and
the whole year work with the phone off or out of range.

Only what the watch cannot compute is pushed from the phone, via
`WCSession.updateApplicationContext` (latest-state-wins, delivered
opportunistically) in `SvatekDnes/Services/WatchSync.swift`:

- **Contact matches** – the `Contacts` framework does not exist on
  watchOS, so these can only come from the phone. The payload is the
  existing `WidgetSnapshot`, which already solves the same problem for the
  widget: given names by day, no contact identifiers, nothing else.
- **Holiday overrides** – the phone forwards the `svatky.json` it already
  downloaded (`HolidayUpdateService.adopt(_:)`), so the watch needs no
  networking of its own.

Out of range the watch degrades to a full calendar without contact names,
rather than to an empty screen. `AppRefresher` is the single choke point
that pushes both.

## Data sources & quality

The nameday calendar was compiled from the Czech Wikipedia article
[„Jmeniny v Česku“](https://cs.wikipedia.org/wiki/Jmeniny) and
cross-validated against [svatkyapi.cz](https://svatkyapi.cz). Entries where
the two sources disagreed were reviewed manually and corrected in favour of
the current civil calendar; the corrections live in the bundled
`Shared/Resources/namedays.json` (and can be amended later via
`namedayOverrides` in the remote file). Public holidays follow zákon
č. 245/2000 Sb.; movable feasts are verified against published Easter
tables for 2026–2030.

## Privacy

- Contacts are read (with permission) and matched **entirely on-device**;
  only their first names leave the phone, synced to the user's own paired
  Apple Watch.
- No analytics, no tracking, no third-party SDKs.
- The only network call the app ever makes is the monthly fetch of the
  static data file from `raw.githubusercontent.com`.

The published privacy policy lives in [`docs/index.html`](docs/index.html)
(cs/en/de in one page, no build step) and is served by GitHub Pages at
<https://norrill.github.io/svatek-dnes/>. That URL is what App Store
Connect has for both **Privacy Policy URL** and **Support URL**, so keep
it stable. Edit the page and push to `main` to publish; the policy's
effective date in the header must be bumped whenever data handling
changes.
