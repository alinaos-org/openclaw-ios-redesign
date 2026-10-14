import OpenClawChatUI
import OpenClawKit
import SwiftUI

// SIMPLE-UI: The ☰ panel — one main chat plus side chats for separate
// projects. Backed by the same session roster and grouping as the classic
// sidebar so both layouts list identical conversations.

struct SimpleChatsSheet: View {
    @Environment(NodeAppModel.self) private var appModel

    let sidebarModel: RootSidebarModel
    let onSelectMain: (String) -> Void
    let onSelectSession: (OpenClawChatSessionEntry) -> Void
    let onNewChat: () -> Void
    let onOpenSettings: () -> Void

    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if self.trimmedQuery.isEmpty {
                        self.mainChatRow
                        SimpleRowDivider(leadingInset: 0)
                            .padding(.vertical, 6)
                    }
                    self.sideChatsHeader
                    if self.sideChatSections.allSatisfy(\.nodes.isEmpty) {
                        self.emptyState
                    } else {
                        ForEach(self.sideChatSections) { section in
                            if let title = section.title?.trimmedNonEmpty, !section.nodes.isEmpty {
                                Text(verbatim: title)
                                    .font(OpenClawType.footnoteSemiBold)
                                    .foregroundStyle(SimplePalette.tertiaryInk)
                                    .padding(.horizontal, SimpleMetric.gutter + 4)
                                    .padding(.top, 12)
                                    .padding(.bottom, 4)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            ForEach(section.nodes) { node in
                                self.sessionRow(node)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .simpleCanvas()
            .searchable(
                text: self.$query,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text("Search chats"))
            .navigationTitle(Text(verbatim: SimpleAgentIdentity.displayName(appModel: self.appModel)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        self.onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(SimplePalette.ink)
                    }
                    .accessibilityLabel(Text("Settings"))
                    .accessibilityIdentifier("Simple.Chats.Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.onNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(SimplePalette.ink)
                    }
                    .accessibilityLabel(Text("New side chat"))
                    .accessibilityIdentifier("Simple.Chats.New")
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var trimmedQuery: String {
        self.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var mainSessionKey: String {
        ChatSessionSidebarModel.selectedSessionKey(
            sessions: self.sidebarModel.sessions,
            currentSessionKey: "main",
            mainSessionKey: self.appModel.mainSessionKey,
            activeAgentID: self.appModel.chatAgentId,
            sessionRoutingContract: self.appModel.chatSessionRoutingContract)
    }

    private var selectedSessionKey: String {
        ChatSessionSidebarModel.selectedSessionKey(
            sessions: self.sidebarModel.sessions,
            currentSessionKey: self.appModel.chatSessionKey,
            mainSessionKey: self.appModel.mainSessionKey,
            activeAgentID: self.appModel.chatAgentId,
            sessionRoutingContract: self.appModel.chatSessionRoutingContract)
    }

    private struct SideChatSection: Identifiable {
        let id: String
        let title: String?
        let nodes: [ChatSessionSidebarModel.Node]
    }

    private var sideChatSections: [SideChatSection] {
        let mainKey = self.mainSessionKey
        let groups = CommandSessionGrouping
            .categories(from: self.sidebarModel.sessions, knownGroups: SessionGroupStore.load())
            .enumerated()
            .map { offset, name in OpenClawChatSessionGroup(name: name, position: offset) }
        return RootSidebarModel.sections(
            sessions: self.sidebarModel.sessions,
            query: self.trimmedQuery,
            currentSessionKey: self.appModel.chatSessionKey,
            mainSessionKey: self.appModel.mainSessionKey,
            activeAgentID: self.appModel.chatAgentId,
            groups: groups,
            sessionRoutingContract: self.appModel.chatSessionRoutingContract,
            now: self.sidebarModel.now)
            .map { section in
                SideChatSection(
                    id: section.id,
                    title: section.title,
                    nodes: section.nodes.filter {
                        $0.session.key.caseInsensitiveCompare(mainKey) != .orderedSame
                    })
            }
    }

    private var mainChatRow: some View {
        let mainKey = self.mainSessionKey
        let isSelected = self.selectedSessionKey.caseInsensitiveCompare(mainKey) == .orderedSame
        return Button {
            self.onSelectMain(mainKey)
        } label: {
            HStack(spacing: 14) {
                SimpleIconTile(systemImage: "bubble.left.fill", tint: SimplePalette.accent, size: 36)
                Text("Main chat")
                    .font(OpenClawType.headline)
                    .foregroundStyle(SimplePalette.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SimpleMetric.gutter + 4)
            .padding(.vertical, 12)
            .background(isSelected ? SimplePalette.fill : Color.clear)
        }
        .buttonStyle(SimpleRowButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("Simple.Chats.Main")
    }

    private var sideChatsHeader: some View {
        HStack {
            Text("Side chats")
                .font(OpenClawType.subheadSemiBold)
                .foregroundStyle(SimplePalette.secondaryInk)
            Spacer(minLength: 0)
            if self.sidebarModel.isRefreshing {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, SimpleMetric.gutter + 4)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityAddTraits(.isHeader)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(self.trimmedQuery.isEmpty
                ? LocalizedStringKey("No side chats yet")
                : LocalizedStringKey("No matching chats"))
                .font(OpenClawType.subheadSemiBold)
                .foregroundStyle(SimplePalette.ink)
            Text(self.trimmedQuery.isEmpty
                ? LocalizedStringKey("Start one for a project you want to keep separate from your main chat.")
                : LocalizedStringKey("Try a different search."))
                .font(OpenClawType.footnote)
                .foregroundStyle(SimplePalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SimpleMetric.gutter + 4)
        .padding(.vertical, 12)
    }

    private func sessionRow(_ node: ChatSessionSidebarModel.Node) -> some View {
        let session = node.session
        let isSelected = session.key.caseInsensitiveCompare(self.selectedSessionKey) == .orderedSame
        return Button {
            self.onSelectSession(session)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: CommandCenterTab.sessionTitle(session))
                        .font(OpenClawType.body)
                        .foregroundStyle(SimplePalette.ink)
                        .lineLimit(1)
                    if let preview = session.lastMessagePreview?.trimmedNonEmpty {
                        Text(verbatim: preview)
                            .font(OpenClawType.footnote)
                            .foregroundStyle(SimplePalette.secondaryInk)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if node.badges.runningCount > 0 {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(Text("Working"))
                }
            }
            .padding(.horizontal, SimpleMetric.gutter + 4)
            .padding(.vertical, 10)
            .background(isSelected ? SimplePalette.fill : Color.clear)
        }
        .buttonStyle(SimpleRowButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("Simple.Chats.Session.\(session.key)")
    }
}
