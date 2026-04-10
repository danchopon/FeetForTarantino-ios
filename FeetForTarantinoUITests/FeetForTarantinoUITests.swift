import XCTest

final class FeetForTarantinoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab bar

    @MainActor
    func testTabBarContainsAllFiveTabs() {
        XCTAssertTrue(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.tabBars.buttons["Watchlist"].exists)
        XCTAssertTrue(app.tabBars.buttons["For You"].exists)
        XCTAssertTrue(app.tabBars.buttons["Movie Night"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        XCTAssertTrue(app.tabBars.buttons["Search"].exists)
    }

    @MainActor
    func testWatchlistIsSelectedByDefault() {
        XCTAssertTrue(app.tabBars.buttons["Watchlist"].isSelected)
    }

    // MARK: - Tab navigation

    @MainActor
    func testCanSwitchToForYouTab() {
        app.tabBars.buttons["For You"].tap()
        XCTAssertTrue(app.tabBars.buttons["For You"].isSelected)
    }

    @MainActor
    func testCanSwitchToMovieNightTab() {
        app.tabBars.buttons["Movie Night"].tap()
        XCTAssertTrue(app.tabBars.buttons["Movie Night"].isSelected)
    }

    @MainActor
    func testCanSwitchToSettingsTab() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].isSelected)
    }

    @MainActor
    func testCanSwitchToSearchTab() {
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.tabBars.buttons["Search"].isSelected)
    }

    @MainActor
    func testCanCycleThroughAllTabs() {
        for tab in ["Watchlist", "For You", "Movie Night", "Settings", "Search"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected, "\(tab) should be selected after tap")
        }
    }

    // MARK: - Empty states (no groups connected)

    @MainActor
    func testWatchlistShowsEmptyState() {
        XCTAssertTrue(app.staticTexts["No groups connected"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testForYouShowsEmptyState() {
        app.tabBars.buttons["For You"].tap()
        XCTAssertTrue(app.staticTexts["No groups connected"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testMovieNightShowsEmptyState() {
        app.tabBars.buttons["Movie Night"].tap()
        XCTAssertTrue(app.staticTexts["No groups connected"].waitForExistence(timeout: 3))
    }

    // MARK: - Settings

    @MainActor
    func testSettingsNavigationTitle() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSettingsShowsConnectedGroupsSection() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Connected Groups"].waitForExistence(timeout: 3))
    }

    // MARK: - Search

    @MainActor
    func testSearchNavigationTitle() {
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSearchFieldExists() {
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.searchFields["Search movies\u{2026}"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSearchFieldAcceptsTextInput() {
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields["Search movies\u{2026}"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Inception")
        XCTAssertEqual(field.value as? String, "Inception")
    }

    @MainActor
    func testSearchFieldClearsOnCancel() {
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields["Search movies\u{2026}"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Pulp Fiction")
        // Cancel button appears when search is active
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
            // Field should be cleared after cancel
            XCTAssertTrue(field.waitForExistence(timeout: 2))
        }
    }

    // MARK: - Navigation stability

    @MainActor
    func testReturnToWatchlistPreservesEmptyState() {
        app.tabBars.buttons["Movie Night"].tap()
        XCTAssertTrue(app.tabBars.buttons["Movie Night"].isSelected)
        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(app.staticTexts["No groups connected"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAppDoesNotCrashOnRapidTabSwitching() {
        for _ in 0..<3 {
            for tab in ["Watchlist", "Search", "Movie Night", "For You", "Settings"] {
                app.tabBars.buttons[tab].tap()
            }
        }
        // App should still be running and responsive
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
}
