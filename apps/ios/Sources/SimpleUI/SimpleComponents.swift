import OpenClawChatUI
import SwiftUI

// SIMPLE-UI: Shared building blocks for the simple layout.

/// Centered agent identity: the mascot overlapping a name capsule, with a
/// live status line underneath the name while the agent works.
///
/// Resolves its own name and status so that only this small view, not the
/// screen hosting it, re-renders as a reply streams in.
struct SimpleAgentHeader: View {
    var action: (() -> Void)?

    @Environment(NodeAppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.simpleTabIsActive) private var isTabActive

    var body: some View {
        let name = SimpleAgentIdentity.displayName(appModel: self.appModel)
        let status = SimpleAgentStatus.resolve(appModel: self.appModel)
        Button {
            self.action?()
        } label: {
            VStack(spacing: -6) {
                OpenClawMascotView(
                    floats: false,
                    mood: status.mood,
                    minimumFrameInterval: 1.0 / 24.0,
                    paused: !self.isTabActive)
                    .frame(width: SimpleMetric.headerAvatarSize, height: SimpleMetric.headerAvatarSize)
                    .zIndex(1)
                self.nameCapsule(name: name, status: status)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(self.action == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(verbatim: status.text ?? String(localized: "Ready")))
        .accessibilityHint(Text("Shows what your agent is up to"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Simple.AgentHeader")
    }

    private func nameCapsule(name: String, status: SimpleAgentStatus) -> some View {
        VStack(spacing: 1) {
            Text(verbatim: name)
                .font(OpenClawType.headline)
                .foregroundStyle(SimplePalette.ink)
                .lineLimit(1)
            if let text = status.text {
                Text(verbatim: text)
                    .font(OpenClawType.caption)
                    .foregroundStyle(
                        status.phase == .needsApproval ? SimplePalette.attention : SimplePalette.secondaryInk)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 7)
        .frame(minWidth: 72)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SimplePalette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SimplePalette.hairline, lineWidth: 0.5)
                }
        }
        .simpleFloatingShadow()
        .animation(self.reduceMotion ? nil : .snappy(duration: 0.25), value: status)
    }
}

/// Floating circular control (☰, ⋯) used at the header's edges.
struct SimpleCircleButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Image(systemName: self.systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(SimplePalette.ink)
                .frame(width: SimpleMetric.circleButtonSize, height: SimpleMetric.circleButtonSize)
                .background {
                    Circle()
                        .fill(SimplePalette.surface)
                        .overlay { Circle().stroke(SimplePalette.hairline, lineWidth: 0.5) }
                }
                .simpleFloatingShadow()
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(self.accessibilityLabel))
        .accessibilityIdentifier(self.accessibilityIdentifier)
    }
}

/// The header row every tab shares: optional edge controls around the
/// centered agent identity. Content scrolls underneath with a soft fade.
struct SimpleTopBar<Leading: View, Trailing: View>: View {
    let onTapAgent: () -> Void
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top) {
                self.leading
                Spacer(minLength: 0)
                self.trailing
            }
            .padding(.top, 6)
            SimpleAgentHeader(action: self.onTapAgent)
                .padding(.horizontal, 64)
        }
        .padding(.horizontal, SimpleMetric.gutter)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: SimplePalette.canvas, location: 0),
                    .init(color: SimplePalette.canvas, location: 0.7),
                    .init(color: SimplePalette.canvas.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }
}

extension SimpleTopBar where Leading == EmptyView {
    init(onTapAgent: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.init(onTapAgent: onTapAgent, leading: { EmptyView() }, trailing: trailing)
    }
}

/// Large left-aligned page title ("Ideas", "Goals").
struct SimpleLargeTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(self.title)
            .font(OpenClawType.title2SemiBold)
            .foregroundStyle(SimplePalette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SimpleMetric.gutter + 4)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Rounded square holding a tinted SF Symbol, used as a row illustration.
struct SimpleIconTile: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: self.systemImage)
            .font(.system(size: self.size * 0.45, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(self.tint)
            .frame(width: self.size, height: self.size)
            .background(
                RoundedRectangle(cornerRadius: SimpleMetric.iconTileRadius, style: .continuous)
                    .fill(self.tint.opacity(0.13)))
            .accessibilityHidden(true)
    }
}

/// Section header with a haloed status dot ("● Tracking").
struct SimpleDotSectionHeader: View {
    let title: Text
    let tint: Color
    let halo: Color

    init(title: LocalizedStringKey, tint: Color, halo: Color) {
        self.title = Text(title)
        self.tint = tint
        self.halo = halo
    }

    /// For titles built at runtime, such as ones with the agent's name.
    init(verbatim title: String, tint: Color, halo: Color) {
        self.title = Text(verbatim: title)
        self.tint = tint
        self.halo = halo
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(self.tint)
                .frame(width: 8, height: 8)
                .padding(5)
                .background(Circle().fill(self.halo))
                .accessibilityHidden(true)
            self.title
                .font(OpenClawType.headline)
                .foregroundStyle(self.tint)
        }
        .padding(.horizontal, SimpleMetric.gutter + 4)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Full-width row press feedback without List chrome.
struct SimpleRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(configuration.isPressed ? SimplePalette.fill : Color.clear)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Thin separator inset to align with row text.
struct SimpleRowDivider: View {
    var leadingInset: CGFloat = SimpleMetric.gutter + 4

    var body: some View {
        Rectangle()
            .fill(SimplePalette.hairline)
            .frame(height: 0.5)
            .padding(.leading, self.leadingInset)
            .accessibilityHidden(true)
    }
}
