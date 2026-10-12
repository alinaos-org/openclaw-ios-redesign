import SwiftUI

// SIMPLE-UI: Card presentation for tool activity, for hosts with a simplified
// layout (the iOS simple layout in this fork). Hosts opt in by setting
// `openClawToolCardStyle`; every other host keeps the compact rows.

/// Host-supplied colors for tool activity cards.
public struct OpenClawChatToolCardStyle: Sendable {
    /// Card fill.
    public var surface: Color
    /// Fill behind the tool's icon.
    public var tile: Color
    /// Icon and completion tint.
    public var accent: Color

    public init(surface: Color, tile: Color, accent: Color) {
        self.surface = surface
        self.tile = tile
        self.accent = accent
    }

    static let cornerRadius: CGFloat = 16
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
