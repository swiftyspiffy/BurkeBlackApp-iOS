import XCTest

// Manual acceptance suite: install the app on a fresh simulator during an active
// election, generate this project's Xcode project with XcodeGen, then run the
// CaptainsUITests scheme on that simulator. Only public browsing is exercised.
@MainActor
final class CaptainsUITests: XCTestCase {
    func testPresentationDraggingAndCrewScrolling() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.swiftyspiffy.BurkeBlackApp")
        app.launch()

        let minimize = app.buttons["captains.minimize"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 30), "The first election alert must open the full Captains UI")
        XCTAssertTrue(app.segmentedControls.buttons["Vote"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["The Crew"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Rankings"].exists)
        capture("Initial full Captains UI")

        minimize.tap()
        let bubble = app.buttons["captains.restore"]
        XCTAssertTrue(bubble.waitForExistence(timeout: 5))
        XCTAssertEqual(bubble.frame.width, bubble.frame.height, accuracy: 1)
        let original = bubble.frame
        bubble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.35)))
        waitUntil { abs(bubble.frame.midX - original.midX) > 60 }
        XCTAssertFalse(minimize.exists, "Dropping the bubble must not also open Captains")
        let moved = bubble.frame
        capture("Moved captain circle")

        app.terminate()
        app.launch()
        XCTAssertTrue(bubble.waitForExistence(timeout: 20))
        XCTAssertFalse(minimize.exists, "Restart must preserve election minimization")
        XCTAssertEqual(bubble.frame.midX, moved.midX, accuracy: 5)
        XCTAssertEqual(bubble.frame.midY, moved.midY, accuracy: 5)
        bubble.tap()
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        app.segmentedControls.buttons["The Crew"].tap()

        let portraits = app.descendants(matching: .any).matching(identifier: "captains.crew.portraits").firstMatch
        let name = app.staticTexts["captains.crew.name"]
        XCTAssertTrue(portraits.waitForExistence(timeout: 20))
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let firstName = name.label
        portraits.swipeLeft()
        waitUntil { name.label != firstName }
        let portraitY = portraits.frame.minY
        portraits.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        waitUntil { portraits.frame.minY < portraitY - 40 }
        let connection = app.descendants(matching: .any).matching(identifier: "captains.connection").firstMatch
        for _ in 0..<3 where !connection.isHittable { app.swipeUp() }
        XCTAssertTrue(connection.isHittable, "Swiping over the portrait must reveal the page footer")
        capture("Crew page footer")

        minimize.tap()
        XCTAssertTrue(bubble.waitForExistence(timeout: 5))
        bubble.tap()
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["The Crew"].isSelected, "Restoring should keep the selected Captains section")
        minimize.tap()
        XCTAssertTrue(bubble.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        waitUntil { app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1).contains(bubble.frame), "The bubble must stay reachable after rotation")
        capture("Captain circle after rotation")
        XCUIDevice.shared.orientation = .portrait
    }

    private func waitUntil(_ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
