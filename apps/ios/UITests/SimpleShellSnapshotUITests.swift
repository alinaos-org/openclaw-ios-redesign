import XCTest

// SIMPLE-UI: Walks the simple layout in screenshot mode (demo gateway data) and keeps a
// screenshot of every surface, so the redesign can be reviewed from CI
// artifacts without a Mac. Run through the OpenClawUITests scheme.
@MainActor
final class SimpleShellSnapshotUITests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Keep going after a missed element so one failure still yields the other screens.
        continueAfterFailure = true
    }

    override func tearDownWithError() throws {
        self.app?.terminate()
        self.app = nil
        try super.tearDownWithError()
    }

    func testSimpleTabsLight() {
        self.captureTabs(appearance: "light")
    }

    func testSimpleTabsDark() {
        self.captureTabs(appearance: "dark")
    }

    func testSimpleAgentProfileSheet() {
        let app = self.launch(appearance: "light")
        let header = app.buttons["Simple.AgentHeader"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10), "Agent header is missing")
        XCTAssertTrue(
            self.tap(header, until: app.buttons["Simple.Profile.activity"]),
            "Profile sheet did not open")
        self.settle()
        self.capture("simple-profile-light")
    }

    func testSimpleChatsSheet() {
        let app = self.launch(appearance: "light")
        let chats = app.buttons["Simple.Chats.Show"].firstMatch
        XCTAssertTrue(chats.waitForExistence(timeout: 10), "Chats button is missing")
        XCTAssertTrue(self.tap(chats, until: app.buttons["Simple.Chats.Main"]), "Chats sheet did not open")
        self.settle()
        self.capture("simple-chats-light")
    }

    func testSimpleChatActionsMenu() {
        let app = self.launch(appearance: "light")
        let actions = app.buttons["Simple.Chat.Actions"].firstMatch
        XCTAssertTrue(actions.waitForExistence(timeout: 10), "Chat actions button is missing")
        let modelSettings = app.buttons["simple-actions-model-settings"]
        XCTAssertTrue(self.tap(actions, until: modelSettings), "Chat actions menu did not open")
        self.settle()
        self.capture("simple-chat-actions-light")
        XCTAssertTrue(
            self.tap(modelSettings, until: app.buttons["simple-model-sign-in"]),
            "Model & thinking sheet did not open")
        self.settle()
        self.capture("simple-model-settings-light")
    }

    func testSimpleApprovalCardLight() {
        self.captureApprovalCard(appearance: "light")
    }

    func testSimpleApprovalCardDark() {
        self.captureApprovalCard(appearance: "dark")
    }

    private func captureApprovalCard(appearance: String) {
        let app = self.launch(appearance: appearance, additionalArguments: ["--openclaw-simple-approval-sample"])
        XCTAssertTrue(app.buttons["simple-approval-allow"].waitForExistence(timeout: 10), "Approval card is missing")
        XCTAssertTrue(app.buttons["simple-approval-deny"].exists, "Deny button is missing")
        self.settle()
        self.capture("simple-approval-\(appearance)")
    }

    func testSimpleOnboardingLight() {
        self.walkOnboarding(appearance: "light")
    }

    func testSimpleOnboardingDark() {
        self.walkOnboarding(appearance: "dark")
    }

    /// First run in the simple layout: welcome, connect, then the demo setup
    /// code through the wizard's manual step to the ready screen and chat.
    private func walkOnboarding(appearance: String) {
        self.addUIInterruptionMonitor(withDescription: "Local network access") { alert in
            guard alert.buttons["Allow"].exists else { return false }
            alert.buttons["Allow"].tap()
            return true
        }
        self.app?.terminate()
        let app = XCUIApplication()
        app.launchArguments += [
            "--openclaw-reset-onboarding",
            "--openclaw-simple-shell",
            "--openclaw-appearance",
            appearance,
        ]
        app.launch()
        self.app = app

        let start = app.buttons["simple-onboarding-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "Welcome screen is missing")
        let trust = app.descendants(matching: .any)["simple-onboarding-trust"]
        XCTAssertTrue(trust.exists, "The first screen must say what a connected agent can use")
        XCTAssertLessThanOrEqual(
            trust.frame.maxY,
            start.frame.minY,
            "The trust note must be visible above Get started without scrolling")
        self.settle()
        self.capture("simple-onboarding-welcome-\(appearance)")

        start.tap()
        // Gives the interruption monitor a chance to answer the local network prompt.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)).tap()
        XCTAssertTrue(
            app.buttons["simple-onboarding-scan"].waitForExistence(timeout: 10),
            "Connect screen is missing")
        self.settle()
        self.capture("simple-onboarding-connect-\(appearance)")

        app.buttons["simple-onboarding-other-ways"].tap()
        let setupCode = app.textFields["Enter setup code"]
        XCTAssertTrue(setupCode.waitForExistence(timeout: 10), "Manual setup step is missing")
        setupCode.tap()
        setupCode.typeText("APPLE-REVIEW-DEMO")
        app.buttons["Dismiss Keyboard"].tap()
        app.buttons["Apply"].tap()

        let done = app.buttons["simple-onboarding-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "Ready screen is missing")
        self.settle()
        self.capture("simple-onboarding-ready-\(appearance)")

        done.tap()
        XCTAssertTrue(
            app.buttons["Simple.Tab.chat"].waitForExistence(timeout: 10),
            "Finishing onboarding should land in the simple layout")
    }

    /// Settings opens in a sheet in the simple layout; resetting onboarding
    /// there must close it and show the first-run screens.
    func testResetOnboardingFromSimpleSettings() {
        let app = self.launch(appearance: "light")
        app.buttons["Simple.Tab.more"].tap()
        let connection = app.buttons["Simple.More.gateway"]
        for _ in 0..<6 where !connection.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(connection.isHittable, "Connection row is missing from More")
        connection.tap()

        // Settings builds its rows lazily, so the last one exists only once scrolled to.
        self.settle()
        let reset = app.buttons["Reset Onboarding"]
        for _ in 0..<12 where !reset.isHittable {
            app.swipeUp()
        }
        guard reset.isHittable else {
            self.capture("simple-reset-missing-light")
            XCTFail("Reset Onboarding is missing from Connection settings")
            return
        }
        reset.tap()
        let confirm = app.alerts["Reset Onboarding?"].buttons["Reset"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Reset confirmation is missing")
        confirm.tap()

        XCTAssertTrue(
            app.buttons["simple-onboarding-start"].waitForExistence(timeout: 15),
            "Resetting onboarding from a simple sheet should show the first-run screens")
        self.capture("simple-onboarding-after-reset-light")
    }

    func testSimpleToolCardsLight() {
        self.captureToolCards(appearance: "light")
    }

    func testSimpleToolCardsDark() {
        self.captureToolCards(appearance: "dark")
    }

    /// The same tool fixture in the classic layout, for before/after review.
    func testClassicToolRowsLight() {
        self.app?.terminate()
        let app = XCUIApplication()
        app.launchArguments += [
            "--openclaw-classic-shell",
            "--openclaw-step-labels-fixture",
            "--openclaw-screenshot-mode",
            "--openclaw-ui-test-readiness",
            "--openclaw-initial-tab",
            "chat",
            "--openclaw-sidebar-visibility",
            "hidden",
            "--openclaw-appearance",
            "light",
        ]
        app.launch()
        self.app = app
        self.expandCompletedWork(in: app)
        let row = self.toolRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Tool rows are missing")
        XCTAssertTrue(
            (row.value as? String ?? "").contains("No result"),
            "The classic layout keeps the unknown-outcome label")
        self.settle()
        self.capture("classic-tool-rows-light")
    }

    private func captureToolCards(appearance: String) {
        let app = self.launch(appearance: appearance, additionalArguments: ["--openclaw-step-labels-fixture"])
        let summary = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@",
            "Ran 3 steps"))
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 30), "Completed work should summarize its steps")
        self.capture("simple-tool-summary-\(appearance)")
        self.expandCompletedWork(in: app)
        let card = self.toolRow(in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Tool cards are missing")
        XCTAssertFalse(
            (card.value as? String ?? "").contains("No result"),
            "Cards leave out the unknown-outcome label")
        self.settle()
        self.capture("simple-tool-cards-\(appearance)")
        card.tap()
        self.settle()
        self.capture("simple-tool-cards-expanded-\(appearance)")
    }

    private func captureTabs(appearance: String) {
        let app = self.launch(appearance: appearance)
        self.assertComposerClearsTabBar(in: app)
        XCTAssertTrue(app.buttons["Simple.Tab.chat"].isSelected, "Chat should be the selected tab")
        XCTAssertFalse(app.buttons["Simple.Tab.goals"].isSelected, "Only the current tab may read as selected")
        self.capture("simple-01-chat-\(appearance)")
        for (offset, tab) in ["library", "ideas", "goals", "more"].enumerated() {
            let button = app.buttons["Simple.Tab.\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab: \(tab)")
            button.tap()
            self.settle()
            self.capture("simple-\(String(format: "%02d", offset + 2))-\(tab)-\(appearance)")
        }
    }

    /// The floating tab bar must never cover the chat's message box.
    private func assertComposerClearsTabBar(in app: XCUIApplication) {
        let input = app.descendants(matching: .any)["chat-message-input"].firstMatch
        let tabBar = app.descendants(matching: .any)["Simple.TabBar"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Message box is missing")
        XCTAssertTrue(tabBar.exists, "Tab bar is missing")
        XCTAssertLessThanOrEqual(
            input.frame.maxY,
            tabBar.frame.minY,
            "The tab bar covers the message box")
    }

    /// Taps `element` until `target` appears. A presentation requested while
    /// the freshly launched app is still settling can be dropped, so one
    /// retry keeps the capture from flaking without hiding a real failure.
    private func tap(_ element: XCUIElement, until target: XCUIElement, attempts: Int = 2) -> Bool {
        for _ in 0..<attempts {
            element.tap()
            if target.waitForExistence(timeout: 5) { return true }
        }
        return false
    }

    /// Finished turns fold their tool calls under "Worked for …"; open it.
    private func expandCompletedWork(in app: XCUIApplication) {
        // "Ran …" in the simple layout, upstream's "Worked …" in the classic one.
        let label = NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Worked", "Ran ")
        let worked = app.buttons.matching(label).firstMatch
        let workedText = app.staticTexts.matching(label).firstMatch
        if worked.waitForExistence(timeout: 30) {
            worked.tap()
        } else if workedText.exists {
            workedText.tap()
        } else {
            XCTFail("Completed work disclosure is missing")
        }
        self.settle()
    }

    /// The fixture's first exec call, by identifier or (if a container's identifier
    /// replaced it) by its label: "Ran a command" as a card, "Exec" as a classic row.
    private func toolRow(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
            "chat-tool-activity-fixture-exec",
            "Exec",
            "Ran a command")).firstMatch
    }

    @discardableResult
    private func launch(appearance: String, additionalArguments: [String] = []) -> XCUIApplication {
        self.app?.terminate()
        let app = XCUIApplication()
        app.launchArguments += [
            "--openclaw-simple-shell",
            "--openclaw-screenshot-mode",
            "--openclaw-ui-test-readiness",
            "--openclaw-sidebar-visibility",
            "hidden",
            "--openclaw-appearance",
            appearance,
        ] + additionalArguments
        app.launch()
        self.app = app
        XCTAssertTrue(
            app.descendants(matching: .any)["RootTabs.Ready"].waitForExistence(timeout: 30),
            "App never reported readiness")
        XCTAssertTrue(app.buttons["Simple.Tab.chat"].waitForExistence(timeout: 10), "Simple tab bar is missing")
        // The chat finishing its first load is the best "settled" signal the demo data offers.
        _ = app.descendants(matching: .any)["chat-message-input"].firstMatch.waitForExistence(timeout: 10)
        self.settle()
        return app
    }

    /// Lets transitions, the mascot, and async gateway fixtures settle before capture.
    private func settle(seconds: TimeInterval = 1.5) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func capture(_ name: String) {
        guard let app else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }
}
