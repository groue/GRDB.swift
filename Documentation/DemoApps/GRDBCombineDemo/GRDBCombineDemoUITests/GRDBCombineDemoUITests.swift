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

    // This test, introduced in 481f6e93, tests the @Query fix added in
    // 68874412. The fix expresses itself when a view defines an @Query
    // property that is replaced in the view initializer, as in 481f6e93.
    //
    // It happens that I did not find that this particular view setup was suited
    // for a demo app. The demo has to find a delicate balance, not too trivial,
    // but without gratuitous complexity.
    //
    // I simplified the demo app in a5ffc52d, and we no longer have any view
    // that defines an @Query property which is replaced in the view
    // initializer. This means that this test no longer checks against
    // 68874412 regressions!
    //
    // Whenever the @Query property wrapper ships with GRDB itself, make sure
    // we test for those regressions!
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
