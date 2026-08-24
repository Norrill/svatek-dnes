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

Three targets, generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen):

| Target | Purpose |
| --- | --- |
| `SvatekDnes` | The app (SwiftUI, `App/`, `Views/`, `Services/`) |
| `SvatekWidget` | WidgetKit extension (home/lock-screen widgets) |
| `SvatekDnesTests` | Unit tests (`Tests/`) |

Both the app and the widget compile the `Shared/` core: models,
`NamedayStore`, `HolidayCalendar` + `EasterCalculator`, `CalendarComposer`,
`NameMatching`, `AppFormat`/design system, and the app-group plumbing
(`AppGroup`, `WidgetSnapshot`).

### Data flow

1. **Bundled baseline** – `Shared/Resources/namedays.json` ships in the app
   bundle; fixed holidays and the Easter computus are compiled in
   (`HolidayCalendar`, `EasterCalculator`).
2. **Remote overrides** – `data/svatky.json` from this repository is served
   via `raw.githubusercontent.com` (URL in `Shared/AppGroup.swift`). When
   present, it replaces the fixed holiday list, the movable feasts for the
   listed years, and individual nameday entries (`namedayOverrides`).
3. **Refresh cycle** – a `BGAppRefreshTask`
   (`cz.fh.svatekdnes.refresh`) runs roughly weekly;
   `HolidayUpdateService` re-downloads the file once the stored copy is
   older than **30 days** (failed attempts retry at most once a day). The
   downloaded file is stored in the app group container so the widget sees
   the same data.

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

## Build & run

```sh
brew install xcodegen
xcodegen generate   # in the repository root
open SvatekDnes.xcodeproj
```

Or from the command line:

```sh
xcodebuild -project SvatekDnes.xcodeproj -scheme SvatekDnes \
	-destination 'platform=iOS Simulator,name=iPhone 16' build
```

Run the tests:

```sh
xcodebuild -project SvatekDnes.xcodeproj -scheme SvatekDnes \
	-destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Releasing to the App Store

Both version numbers live in `project.yml` under `settings.base` and are
inherited by every target, so the app and the widget always ship the same
version (Apple requires that they match). Bump them in **one place**:

- `MARKETING_VERSION` – the user-facing version (`1.1.0`, semver).
- `CURRENT_PROJECT_VERSION` – the build number. Must increase on **every**
  upload to App Store Connect, even when the marketing version stays the
  same (e.g. a rejected build resubmitted with a fix).

Release steps:

1. Bump the versions in `project.yml`, then `xcodegen generate`.
2. Run the unit tests (command above) – they also guard the localization
   catalog (raw-key leaks, plural formats, the 29. 2. leap-day rendering).
3. If the UI changed, refresh the store screenshots: run
   `ScreenshotUITests` on a **6.9-inch** simulator (iPhone 17 Pro Max);
   the App Store requires 1320×2868 portrait for that size and scales the
   rest down from it.
4. Archive and upload: Xcode → Product → Archive → Distribute App →
   App Store Connect. (CLI alternative:
   `xcodebuild -project SvatekDnes.xcodeproj -scheme SvatekDnes
   -destination 'generic/platform=iOS' archive`, then upload the archive
   with the Organizer or Transporter.)

   **If the upload fails with error 90035 "Invalid Signature"** even
   though signing is automatic: the direct upload path ships the
   archive's development-signed binaries without re-signing (observed
   with Xcode 26 / first upload on a fresh team). Work around it by
   exporting first – `xcodebuild -exportArchive` with
   `method: app-store-connect`, `destination: export`,
   `signingStyle: automatic` – which correctly re-signs the app and the
   widget with the Apple Distribution certificate, and then upload the
   resulting `.ipa` with the Transporter app (or
   `xcrun altool --upload-app -f SvatekDnes.ipa -t ios`).
5. Smoke-test the build via TestFlight on a real device – notifications,
   the widget and the contacts flow behave differently than in the
   simulator.
6. Submit for review in App Store Connect with release notes for each
   locale (cs, en, de), and tag the release: `git tag v1.1.0 && git push
   --tags`.

There is no CI and no fastlane – the process is deliberately manual; the
whole release takes a few minutes of hands-on time.

## Updating the holiday data

1. Edit [`data/svatky.json`](data/svatky.json) – fix a holiday name, add
   movable feasts for a new year, or add `namedayOverrides` entries.
2. Bump the `updated` field (ISO date).
3. Push to `main`.

Installed apps pick the change up within roughly a month (30-day staleness
window checked by a weekly background task; users can also trigger the
refresh manually from Nastavení). If a year is missing from `movable`, the
app falls back to the built-in Easter computus, so the app keeps working
correctly even if this file is never updated again.

The file must decode into `RemoteDataFile`
(`Shared/HolidayUpdateService.swift`): `version`, `updated`,
`fixedHolidays` (replaces the whole built-in list when present), `movable`
(year string → list, replaces the computus for that year), and
`namedayOverrides` (per-day `NamedayEntry` patches). Validate before
pushing:

```sh
python3 -m json.tool data/svatky.json > /dev/null
```

## Privacy

- Contacts are read (with permission) and matched **entirely on-device**;
  they never leave the phone.
- No analytics, no tracking, no third-party SDKs.
- The only network call the app ever makes is the monthly fetch of the
  static data file from `raw.githubusercontent.com`.

## CarPlay

CarPlay is intentionally not supported. Apple restricts CarPlay to a fixed
set of approved app categories (navigation, audio, communication, EV
charging, …) – a nameday calendar does not qualify, so no CarPlay
entitlement would ever be granted.
