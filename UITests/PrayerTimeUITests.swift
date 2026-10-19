import XCTest

/// End-to-end check against the public source, separate from deterministic core tests.
final class PrayerTimeUITests: XCTestCase {
    @MainActor
    func testSelectMosqueAndBrowseNativePages() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let choose = app.buttons["onboarding-choose-mosque"]
        XCTAssertTrue(choose.waitForExistence(timeout: 15))
        capture(app, "01-welcome")
        choose.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("Masjid Aisha")
        let mosque = app.buttons["mosque-1"]
        XCTAssertTrue(mosque.waitForExistence(timeout: 45), "Live mosque directory did not load")
        capture(app, "02-mosque-search")
        mosque.tap()

        let fajr = app.staticTexts["Fajr"].firstMatch
        XCTAssertTrue(fajr.waitForExistence(timeout: 45), "Live selected-mosque timetable did not load")
        capture(app, "03-home")

        app.swipeUp()
        let jummah = app.buttons["jummah"]
        XCTAssertTrue(jummah.waitForExistence(timeout: 5))
        jummah.tap()
        XCTAssertTrue(app.staticTexts["Bayaan"].waitForExistence(timeout: 5))
        capture(app, "04-jummah")
        app.navigationBars.buttons.firstMatch.tap()

        let monthly = app.buttons["monthly-timetable"]
        if !monthly.isHittable { app.swipeUp() }
        monthly.tap()
        capture(app, "05-monthly-timetable")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["choose-mosque"].waitForExistence(timeout: 5))
        capture(app, "06-settings")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
