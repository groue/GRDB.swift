//
//  GRDBCombineDemoUITests.swift
//  GRDBCombineDemoUITests
//
//  Created by Peter Steinberger on 08.04.21.
//

import XCTest

class GRDBCombineDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func runApp() -> XCUIApplication {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        // We enforce a fresh database to ensure 8 random players.
        app.launchArguments = ["-reset", "-fixedTestData"]
        app.launch()
        return app
    }

    func testInitialSortingIsByScore() throws {
        let app = runApp()

        let getFirstCell = { () -> XCUIElement in
            app.tables.element(boundBy: 0).cells.element(boundBy: 0)
        }

        // Given default sorting, Henriette must be on top
        XCTAssertEqual(getFirstCell().label, "Craig, 8 points")

        // Reverse sorting will bring Arthur on top (sort by name)
        app.buttons["Score"].tap()
        XCTAssertEqual(getFirstCell().label, "Arthur, 5 points")
    }

    func testListAndAddPlayer() throws {
        let app = runApp()

        // Ensure we have 8 players visible
        XCTAssert(app.tables.cells.count == 8)

        // add a player
        app.buttons["New Player"].tap()

        let playerNameField = app.textFields["Player Name"]
        playerNameField.tap()
        playerNameField.typeText("Tim Apple")

        app.buttons["Save"].tap()

        // This is suboptimal, but we need to wait for the animation to finish
        // A better way could be to disable animations globally,
        // and/or a hook to detect when the async fetch completes.
        sleep(2)

        XCTAssert(app.tables.cells.count == 9)
    }
}
