# Prayer Time

A native iOS 27 app for Leicester mosque prayer times. Built with SwiftUI,
Apple system colours, SF Symbols and native Liquid Glass navigation.

## In the app

- **Home:** your mosque, next jamaat countdown, today's jamaat and beginning times.
- **Jummah:** the mosque's published programme, retaining Bayaan, Azaan and Khutba labels.
- **Monthly timetable:** choose a day on Apple's native calendar and read its times underneath.
- **Settings:** search and select your mosque, choose automatic/light/dark appearance,
  and learn about the data. Mosque details include address, notes and Apple Maps.
- **Notifications:** independently enable Beginning and Jamaat reminders for each
  prayer, with your own number of minutes before each event (zero means on time).
- **Widgets:** small, medium and large Home Screen widgets, plus inline, circular
  and rectangular Lock Screen widgets. Edit each widget to choose Beginning or Jamaat.
- **Accent colour:** Settings → Appearance → Accent colour & icon. Nine Apple system
  colours, with matching alternate mosque icons and contrasting plain backgrounds.

No account, API key, location permission, hosted backend or analytics. Selection and
the last successful timetable stay on the device. Missing source values remain
missing, except Maghrib beginning falls back to jamaat when no separate beginning
time is published. A published beginning always takes priority. All prayer
dates/times use **Europe/London**, including DST, even abroad.

## Build from Windows with GitHub

Push this folder to [LeicesterPrayerTimes](https://github.com/huzaifah1530-bot/LeicesterPrayerTimes).
The **Build Prayer Time** workflow runs automatically on `main` and pull requests,
or from **Actions → Build Prayer Time → Run workflow**.

It generates an Xcode project with XcodeGen, then builds and packages the device app
on GitHub's `xcode-27` macOS runner. The workflow only produces an unsigned IPA;
it does not run tests or build a simulator app. Download it under the completed run's **Artifacts**:

- `PrayerTime-unsigned-IPA`: an unsigned device app, for signing with your own tools.

**The unsigned IPA cannot be installed directly.** Sign it using SideStore/AltStore
or your normal signing workflow. App Store/TestFlight distribution requires your
Apple Developer account, signing setup and an archive/export workflow; this build
does not publish to the App Store. Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`
if your signing setup needs a different identifier.

The IPA includes the WidgetKit extension. **When signing, preserve and provision
the App Group `group.uk.prayertime.app` for both the app and widget extension.**
If your signing service remaps identifiers, use the same remapped App Group in both
targets and `WidgetData.groupID`. This enables automatic mosque sharing. **Widgets
also work without an App Group:** touch and hold the widget → Edit Widget → Mosque,
then select your masjid. The widget fetches its timetable directly and keeps its own
offline copy. Each widget can use a different mosque. If an older widget still shows
the setup message after updating, edit its configuration or remove and re-add it.

Notifications are local and require permission requested from Settings → Notifications.
The app schedules the nearest 63 enabled reminders, within the published timetable,
and refills the queue when opened or refreshed. Open it regularly, especially at a
new month. iOS controls delivery, Focus behaviour and widget background refresh.
Changing mosque removes old pending reminders. No reminders are invented for
unpublished times, apart from the documented Maghrib beginning fallback. Widgets can fetch the selected mosque's latest timetable in the
background, but this does not refill the app's local notification queue.

GitHub standard hosted runners are free for public repositories; private repositories
use the account's included minutes and billing rules. Runner availability and pricing
are controlled by GitHub. See [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
and the [Xcode 27 runner announcement](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/).

## Build on a Mac

Install Xcode 27 and XcodeGen (`brew install xcodegen`), then:

```sh
xcodegen generate
open PrayerTime.xcodeproj
```

Choose your signing team and a device or simulator in Xcode. The app requires iOS 27.
The reusable parser package itself supports iOS 18/macOS 14 and Swift 6.

```sh
swift test
```

## Data and scraping

The app makes HTTPS requests directly to:

- `https://www.salaahtimes.co.uk/Timetable/TodaysTimes` for mosque names and stable IDs.
- `https://www.salaahtimes.co.uk/Mosque/Details/{id}` for each selected mosque's
  monthly jamaat table, beginning table, Jummah entries, address and notes.

Only the selected mosque is fetched. It refreshes on launch/foreground when needed,
every 15 minutes while Home is open, at UK day changes, and on pull to refresh.
No bulk background crawling. DOM parsing uses pinned SwiftSoup 2.8.8, rather than
regular expressions. Unexpected columns, invalid dates and malformed non-empty
time cells produce an error. Empty cells never shift the columns. Beginning times
are never inherited from another mosque. For Maghrib only, the app uses jamaat as
a beginning-time fallback when the mosque hasn't published a separate beginning
time. Raw source values remain intact. This applies to the app, widgets and reminders.

On Fridays (Europe/London), jamaat widgets replace Dhuhr with the mosque's published
Jummah services. All services appear in the medium/large timetable, and the next-event
summary moves to the next available service. The actual jamaat/prayer time is preferred
when published; otherwise Khutba, Azaan or Bayaan is shown with its original stage label.
Missing Jummah is shown as not published; a normal Dhuhr time is never relabelled as
Jummah. Beginning widgets retain the Dhuhr prayer window.

Research: [East London Mosque explains Friday prayer replacing Zuhr](https://www.eastlondonmosque.org.uk/prayers).
[Bashir Ahmed Masjid distinguishes khutbah from the actual prayer time](https://www.bashirahmedmasjid.co.uk/news/dynamic/26/important-notice-change-to-jumu-ah-prayer-from-friday-24th-september).
The mosque-specific service labels and times come from Salaah Times, not these example
mosques. Programmes can change, including around BST/GMT changes; widgets periodically
fetch the current published programme.

The source dates omit years; the parser selects a matching weekday/date within
62 days of retrieval, including year boundaries. Saved data retains the resolved
year and retrieval timestamp. Old month data is never presented as today's times.
Jummah programmes are whatever the mosque currently publishes, and may change.
Use the source link to check announcements. This project is independent of Salaah
Times Leicester and the listed mosques; timetable content belongs to its publishers.

`scripts/audit_source.py` checks the public source shape from Windows using only
Python's standard library. Run `python scripts/audit_source.py` for a small live
sample, or `--all` for all listed mosques. Tests use October 2026 HTML snapshots,
not the network, so CI is repeatable. Do not regenerate those fixtures without
updating their test retrieval date.

## Project map

| Path | Purpose |
| --- | --- |
| `PrayerTime/` | Native app, state, offline cache and screens |
| `PrayerTimeWidgets/` | Home Screen and Lock Screen WidgetKit extension |
| `Sources/PrayerTimeCore/` | Data types, HTML parser and network client |
| `Tests/PrayerTimeCoreTests/` | Source fixtures and parser/time tests |
| `project.yml` | Reproducible XcodeGen configuration |
| `.github/workflows/build.yml` | Device build and unsigned IPA |
| `scripts/make_icon.py` | Reproducible original mosque icon; requires Pillow |
| `docs/design.md` | Design and data decisions |

Windows cannot run Xcode or the iOS Simulator. The macOS CI build is the compilation
check; final interaction, VoiceOver and device layout checks belong on an iPhone,
iPad or Mac simulator. The UI supports Dynamic Type, system dark mode and system
accessibility material settings by using standard SwiftUI components.

SwiftSoup is MIT licensed; its licence is included in the app and
`THIRD_PARTY_NOTICES.md`.
