import OpenClawChatUI
import SwiftUI

// SIMPLE-UI: How `ChatProTab` presents itself. Classic keeps the upstream
// navigation-bar header untouched; the simple chrome swaps in the centered
// agent header and light-blue user bubbles.

enum ChatProTabChrome {
    case classic
    case simple(onTapAgent: () -> Void)

    var isSimple: Bool {
        switch self {
        case .classic: false
        case .simple: true
        }
    }
}

/// Applies the simple chrome to `ChatProTab`: switches the composer to a
/// single-row pill, paints the shared canvas (the chat skips its own
/// background in this chrome), hides the navigation bar,
/// adds the shared agent header, and stops read-aloud when the chat tab is
/// hidden (simple-layout tabs stay mounted, so `onDisappear` never fires).
/// Classic chrome passes the content through unchanged.
struct SimpleChatChromeModifier<TopBar: View>: ViewModifier {
    let chrome: ChatProTabChrome
    let topBar: (@escaping () -> Void) -> TopBar
    let onLeaveTab: () -> Void

    @Environment(\.simpleTabIsActive) private var isTabActive

    func body(content: Content) -> some View {
        if case let .simple(onTapAgent) = self.chrome {
            content
                .environment(\.openClawComposerPillStyle, .simpleLayout)
                .environment(\.openClawToolCardStyle, .simpleLayout)
                .simpleCanvas()
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    self.topBar(onTapAgent)
                }
                .onChange(of: self.isTabActive) { _, isActive in
                    if !isActive { self.onLeaveTab() }
                }
        } else {
            content
        }
    }
}

/// Empty-chat copy for the simple chrome: everyday tasks, not gateway admin.
enum SimpleStarterPrompts {
    static var intro: String {
        String(localized: "What can I take off your plate?")
    }

    static var chat: [OpenClawChatView.StarterPrompt] {
        [
            OpenClawChatView.StarterPrompt(
                id: "simple-plan-week",
                title: String(localized: "Plan my week"),
                prompt: String(localized: "Look at my calendar for the next 7 days and help me plan the week.")),
            OpenClawChatView.StarterPrompt(
                id: "simple-reminder",
                title: String(localized: "Remind me about something"),
                prompt: String(localized: "I need a reminder. Ask me what it's for and when, then set it up.")),
            OpenClawChatView.StarterPrompt(
                id: "simple-what-can-you-do",
                title: String(localized: "What can you do for me?"),
                prompt: String(localized: """
                What kinds of things can you take care of for me? Give me a few concrete examples based on \
                what you can access right now.
                """)),
        ]
    }
}

extension OpenClawChatToolCardStyle {
    /// Quiet card with a light-blue icon tile, titled in plain language
    /// ("Running a command…", "Ran a command").
    static var simpleLayout: OpenClawChatToolCardStyle {
        OpenClawChatToolCardStyle(
            surface: SimplePalette.fill,
            tile: SimplePalette.accentTint,
            accent: SimplePalette.accent,
            title: { context in
                SimpleToolVocabulary.title(
                    rawName: context.toolName,
                    displayName: context.displayName,
                    isRunning: context.isRunning)
            })
    }
}

extension OpenClawChatComposerPillStyle {
    /// Solid field with a hairline and the layout's blue send button.
    static var simpleLayout: OpenClawChatComposerPillStyle {
        OpenClawChatComposerPillStyle(
            surface: SimplePalette.surface,
            border: SimplePalette.hairline,
            accent: SimplePalette.accent)
    }
}
