import SwiftUI

// SIMPLE-UI: Five icon-only destinations in a floating capsule, the selected one
// sitting on a soft grey pill.

enum SimpleTab: String, CaseIterable, Identifiable, Hashable {
    case chat
    case library
    case ideas
    case goals
    case more

    var id: String {
        self.rawValue
    }

    var title: String {
        switch self {
        case .chat: String(localized: "Chat")
        case .library: String(localized: "Library")
        case .ideas: String(localized: "Ideas")
        case .goals: String(localized: "Goals")
        case .more: String(localized: "More")
        }
    }

    var systemImage: String {
        switch self {
        case .chat: "bubble.left"
        case .library: "doc.text"
        case .ideas: "lightbulb"
        case .goals: "checkmark.square"
        case .more: "square.grid.2x2"
        }
    }
}

struct SimpleTabBar: View {
    @Binding var selection: SimpleTab
    /// Small attention dots, e.g. failing automations on Goals.
    var attention: Set<SimpleTab> = []

    @Namespace private var selectionNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SimpleTab.allCases) { tab in
                Button {
                    self.select(tab)
                } label: {
                    self.item(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: tab.title))
                .accessibilityValue(self.attention.contains(tab) ? Text("Needs attention") : Text(verbatim: ""))
                // Only the current tab reads as selected; the icon (a checkbox on
                // Goals) must not contribute a "selected" state of its own.
                .accessibilityAddTraits(self.selection == tab ? .isSelected : [])
                .accessibilityRemoveTraits(self.selection == tab ? [] : .isSelected)
                .accessibilityIdentifier("Simple.Tab.\(tab.rawValue)")
            }
        }
        .padding(6)
        .background {
            Capsule()
                .fill(SimplePalette.tabBar)
                .overlay { Capsule().stroke(SimplePalette.hairline, lineWidth: 0.5) }
        }
        .simpleFloatingShadow()
        .frame(maxWidth: SimpleMetric.tabBarMaxWidth)
        .padding(.horizontal, SimpleMetric.gutter + 4)
        .sensoryFeedback(.selection, trigger: self.selection)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Simple.TabBar")
    }

    private func item(_ tab: SimpleTab) -> some View {
        ZStack {
            if self.selection == tab {
                Capsule()
                    .fill(SimplePalette.tabSelection)
                    .matchedGeometryEffect(id: "selection", in: self.selectionNamespace)
            }
            Image(systemName: tab.systemImage)
                .font(.system(size: 21, weight: self.selection == tab ? .semibold : .regular))
                .foregroundStyle(SimplePalette.ink)
                .accessibilityHidden(true)
                .overlay(alignment: .topTrailing) {
                    if self.attention.contains(tab) {
                        Circle()
                            .fill(SimplePalette.attention)
                            .frame(width: 7, height: 7)
                            .offset(x: 4, y: -2)
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: SimpleMetric.tabBarItemHeight)
        .contentShape(Capsule())
    }

    private func select(_ tab: SimpleTab) {
        guard self.selection != tab else { return }
        withAnimation(self.reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
            self.selection = tab
        }
    }
}
