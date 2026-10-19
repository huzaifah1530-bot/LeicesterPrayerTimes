// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrayerTimeCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "PrayerTimeCore", targets: ["PrayerTimeCore"])],
    dependencies: [.package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.8.8")],
    targets: [
        .target(name: "PrayerTimeCore", dependencies: ["SwiftSoup"]),
        .testTarget(name: "PrayerTimeCoreTests", dependencies: ["PrayerTimeCore"], resources: [.copy("Fixtures")])
    ]
)
