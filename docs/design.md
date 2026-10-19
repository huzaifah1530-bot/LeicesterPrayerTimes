# Prayer Time

Native SwiftUI iPhone and iPad app for iOS 27. Home and Settings are the only tabs.
Use Apple system colours, SF Symbols, large navigation titles, grouped lists,
native menus, pickers, sheets and Liquid Glass navigation chrome. No custom
navigation imitation, fonts, gradients, or brand palette. A blue mosque silhouette
on a plain white background is the app icon.

Monthly timetables now use SwiftUI's graphical DatePicker, constrained to the
published date range in Europe/London. Selected-day times appear below it.
Settings provides independent beginning/jamaat reminder toggles and minute offsets
for each of the five daily prayers. A serial notification worker replaces the
nearest 63 pending requests after preference, schedule or mosque changes. Missing
times never generate reminders. Permission is requested only on user action.
Notifications are replenished by opening/refreshing the app, not indefinitely in
the background. WidgetKit includes all three Home Screen sizes and all three Lock
Screen accessory families, configurable between beginning and jamaat. Timelines
advance at published prayer changes and UK midnight. App and extension share a
snapshot through an App Group; signing must provision it for both targets.

Home shows the selected mosque, next published jamaat, today's jamaat and
beginning times. Separate destinations show Jummah, a day-by-day monthly
timetable and mosque details. Settings contains searchable mosque selection,
appearance and data information. First launch invites selection without choosing
a mosque on the user's behalf.

Fetch the public Salaah Times Leicester directory and each selected mosque's
detail page with URLSession. SwiftSoup parses the actual HTML. No backend,
API keys or credentials. Keep prayer labels and missing cells distinct; never
borrow beginning times from another mosque or calculate missing prayer times.
Parse all dates in Europe/London, validate weekday/month against fetch date,
keep the entire current month, handle December/January rollover and DST.
Jummah is a sequence of labelled source entries, preserving multiple services.
Cache per mosque atomically in Application Support; show saved age and failures.
Cancel obsolete requests when selection changes. Refresh on foreground, UK date
change and pull to refresh, with a 15-minute successful-fetch interval.

Validation: saved real HTML fixtures, parser/date/countdown tests in the Swift
package, live source audit on Windows, package tests and simulator/device builds
on GitHub's Xcode 27 runner. No Xcode or iOS simulator is available on Windows;
do not claim local iOS compilation or visual verification.

