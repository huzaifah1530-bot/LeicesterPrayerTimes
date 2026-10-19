# Prayer Time implementation plan

1. Add a Swift package with real-source fixtures and tests for directory HTML,
   month tables, missing cells, Jummah labels, malformed pages, London dates,
   DST and next jamaat. Implement typed models, parser and network client.
2. Add observable app state with persisted selection, per-mosque disk caching,
   cancellation, foreground and date refresh, and explicit offline/error states.
3. Build native Home and Settings tabs, searchable mosque selection, prayer
   detail, Jummah, monthly timetable, mosque details, appearance and about pages.
4. Add a vector mosque icon and reproducible PNG assets, XcodeGen project,
   GitHub build.yml, live source audit and user setup documentation.
5. Run available checks, review all data/UI boundaries, document checks requiring
   macOS, and leave the project ready for the user's GitHub repository.
