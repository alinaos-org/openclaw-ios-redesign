import SwiftUI

// SIMPLE-UI: Card presentation for tool activity, for hosts with a simplified
// layout (the iOS simple layout in this fork). Hosts opt in by setting
// `openClawToolCardStyle`; every other host keeps the compact rows.

/// What a host needs to name a tool call in its own words.
public struct OpenClawChatToolCardTitleContext: Sendable {
    /// The gateway's tool name, e.g. `exec` or `web_fetch`.
    public let toolName: String
    /// The tool registry's display title, e.g. "Exec".
    public let displayName: String
    public let isRunning: Bool
}

/// Host-supplied presentation for tool activity cards.
public struct OpenClawChatToolCardStyle: Sendable {
    /// Card fill.
    public var surface: Color
    /// Fill behind the tool's icon.
    public var tile: Color
    /// Icon and completion tint.
    public var accent: Color
    /// Card title in the host's words; nil keeps the registry title.
    public var title: (@Sendable (OpenClawChatToolCardTitleContext) -> String?)?

    public init(
        surface: Color,
        tile: Color,
        accent: Color,
        title: (@Sendable (OpenClawChatToolCardTitleContext) -> String?)? = nil)
    {
        self.surface = surface
        self.tile = tile
        self.accent = accent
        self.title = title
    }

    static let cornerRadius: CGFloat = 16

    /// "Ran 3 steps · 1s" for a finished turn's folded work; nil when the turn
    /// ran no tools, so the upstream "Worked for …" label stays.
    static func completedWorkSummary(_ work: ChatTranscriptRow.CompletedWork) -> String? {
        let steps = work.messages.reduce(0) { count, message in
            count + message.content.count(where: \.isToolCall)
        }
        guard steps > 0 else { return nil }
        let ran = steps == 1
            ? String(localized: "Ran 1 step")
            : String(format: String(localized: "Ran %lld steps"), Int64(steps))
        guard let milliseconds = work.durationMilliseconds else { return ran }
        return "\(ran) · \(ChatWorkingDurationFormatter.compact(milliseconds: milliseconds))"
    }
}

extension EnvironmentValues {
    /// Non-nil draws each tool call as a card: icon tile, title, what it is
    /// doing, and a trailing status, with its result inside when expanded.
    @Entry public var openClawToolCardStyle: OpenClawChatToolCardStyle?
}

/// The tool row's container: a card when the host opted in, otherwise the
/// upstream work style.
struct ChatToolCardSurface: ViewModifier {
    let style: OpenClawChatToolCardStyle?

    func body(content: Content) -> some View {
        if let style {
            content
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: OpenClawChatToolCardStyle.cornerRadius, style: .continuous)
                        .fill(style.surface))
        } else {
            content.modifier(ChatWorkCardStyle())
        }
    }
}
