import SwiftUI

// SIMPLE-UI: Single-row "pill" composer for hosts with a simplified layout
// (the iOS simple layout in this fork). Hosts opt in by setting
// `openClawComposerPillStyle`; every other host keeps the clean card.

/// Host-supplied colors for the pill composer.
public struct OpenClawChatComposerPillStyle: Sendable {
    /// Field fill.
    public var surface: Color
    /// Hairline around the field.
    public var border: Color
    /// Send button fill; the glyph on it is white.
    public var accent: Color

    public init(surface: Color, border: Color, accent: Color) {
        self.surface = surface
        self.border = border
        self.accent = accent
    }

    static let cornerRadius: CGFloat = 24
}

extension EnvironmentValues {
    /// Non-nil switches the iOS clean composer to one row: attachments, the
    /// growing draft, then voice and send. Model, effort, context, and
    /// permission controls stay in the full composer.
    @Entry public var openClawComposerPillStyle: OpenClawChatComposerPillStyle?

    /// Bumped by a host to open model sign-in from its own menu. The pill
    /// composer shows the sign-in link only while sign-in is needed.
    @Entry public var openClawModelSignInRequest = 0
}

#if os(iOS)
extension OpenClawChatComposer {
    var pillEditorRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            self.cleanAttachmentMenu
            self.editorOverlay
                .frame(maxWidth: .infinity, minHeight: self.textMinHeight, alignment: .leading)
                // Centers a single line against the 44pt controls; longer drafts grow upward.
                .padding(.vertical, max(0, (self.cleanControlHeight - self.textMinHeight) / 2))
            HStack(spacing: 0) {
                self.cleanCaptureAndPrimaryControls
            }
        }
        .padding(.horizontal, 4)
    }
}
#endif

/// Chooses the composer field: the clean card's glass, or the pill's solid
/// field when the host opted in.
struct ChatComposerSurfaceSelector: ViewModifier {
    let cornerRadius: CGFloat
    let pillStyle: OpenClawChatComposerPillStyle?

    func body(content: Content) -> some View {
        if let pillStyle {
            content.modifier(PillChatComposerSurface(style: pillStyle))
        } else {
            content.modifier(CleanChatComposerSurface(cornerRadius: self.cornerRadius))
        }
    }
}

/// Solid, softly shadowed field used by the pill composer instead of the
/// clean card's glass.
struct PillChatComposerSurface: ViewModifier {
    let style: OpenClawChatComposerPillStyle

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: OpenClawChatComposerPillStyle.cornerRadius, style: .continuous)
        content
            .background(shape.fill(self.style.surface))
            .overlay(shape.strokeBorder(self.style.border, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }
}
