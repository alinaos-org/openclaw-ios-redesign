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
        XCTAssertTrue(
            app.descendants(matching: .any)["chat-tool-activity-fixture-exec"].waitForExistence(timeout: 30),
            "Tool rows are missing")
        self.settle()
        self.capture("classic-tool-rows-light")
    }

    private func captureToolCards(appearance: String) {
        let app = self.launch(appearance: appearance, additionalArguments: ["--openclaw-step-labels-fixture"])
        let card = app.descendants(matching: .any)["chat-tool-activity-fixture-exec"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Tool cards are missing")
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
