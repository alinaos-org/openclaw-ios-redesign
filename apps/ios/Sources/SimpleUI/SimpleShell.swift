import OpenClawChatUI
import OpenClawKit
import SwiftUI
import UIKit

// SIMPLE-UI: Root of the simple layout: five tabs under a shared agent header
// and a floating tab bar. RootTabs owns every sheet (destinations, chats,
// profile) through its single presenter, plus onboarding, gateway problem
// toasts, trust prompts, and approval dialogs, so this view only decides
// what the main surface shows.

struct SimpleShell: View {
    typealias Destination = RootTabs.SidebarDestination

    @Environment(NodeAppModel.self) private var appModel

    @Binding var selectedTab: SimpleTab
    let sidebarModel: RootSidebarModel
    let openDestination: (Destination) -> Void
    let openChats: () -> Void
    let openProfile: () -> Void
    let useClassicInterface: () -> Void

    @State private var mountedTabs: Set<SimpleTab> = [.chat]
    @State private var isKeyboardVisible = false

    /// Shorter keyboard frames are the iPad shortcut bar over a hardware keyboard.
    private static let softwareKeyboardMinimumHeight: CGFloat = 120

    var body: some View {
        ZStack {
            ForEach(SimpleTab.allCases) { tab in
                if self.mountedTabs.contains(tab) {
                    self.root(for: tab)
                        .environment(\.simpleTabIsActive, self.selectedTab == tab)
                        .opacity(self.selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(self.selectedTab == tab)
                        .accessibilityHidden(self.selectedTab != tab)
                }
            }
        }
        // Drawn as an overlay; each tab reserves room for it with
        // `simpleTabBarClearance` inside its own navigation stack.
        .overlay(alignment: .bottom) {
            if self.isTabBarVisible {
                SimpleTabBar(selection: self.$selectedTab, attention: self.attentionTabs)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .simpleCanvas()
        .tint(SimplePalette.accent)
        .onChange(of: self.selectedTab, initial: true) { _, tab in
            self.mountedTabs.insert(tab)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            guard (frame?.height ?? 0) >= Self.softwareKeyboardMinimumHeight else { return }
            withAnimation(.snappy(duration: 0.2)) { self.isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.snappy(duration: 0.2)) { self.isKeyboardVisible = false }
        }
    }

    // MARK: Tabs

    @ViewBuilder
    private func root(for tab: SimpleTab) -> some View {
        switch tab {
        case .chat:
            NavigationStack {
                ChatProTab(
                    headerSidebarAction: self.chatsAction,
                    openSettings: { self.openDestination(.gateway) },
                    chrome: .simple(onTapAgent: self.openProfile))
                    .simpleTabBarClearance(self.isTabBarVisible)
            }
        case .library:
            NavigationStack {
                self.withTopBar {
                    VStack(spacing: 0) {
                        SimpleLargeTitle("Library")
                        AgentWorkspaceDirectoryList(agentId: self.libraryAgentID, path: "")
                            .scrollContentBackground(.hidden)
                    }
                    .simpleCanvas()
                }
            }
        case .ideas:
            NavigationStack {
                self.withTopBar {
                    SimpleIdeasScreen(ideas: SimpleIdeaCatalog.starter) { idea in
                        self.startInChat(idea.prompt)
                    }
                }
            }
        case .goals:
            NavigationStack {
                self.withTopBar(
                    trailing: { self.goalsMenu },
                    content: { self.goalsScreen })
            }
        case .more:
            NavigationStack {
                self.withTopBar {
                    SimpleMoreScreen(
                        open: self.openDestination,
                        useClassicInterface: self.useClassicInterface)
                }
            }
        }
    }

    private var goalsScreen: some View {
        SimpleGoalsScreen(
            jobs: self.sidebarModel.cronJobs,
            onOpenJob: { _ in self.openDestination(.cron) },
            onCreate: { template in self.startInChat(template.prompt) })
            .refreshable {
                await self.sidebarModel.refresh(appModel: self.appModel)
            }
    }

    private func withTopBar(@ViewBuilder content: () -> some View) -> some View {
        self.withTopBar(trailing: { EmptyView() }, content: content)
    }

    private func withTopBar(
        @ViewBuilder trailing: () -> some View,
        @ViewBuilder content: () -> some View) -> some View
    {
        content()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                SimpleTopBar(onTapAgent: self.openProfile, trailing: trailing)
            }
            .simpleTabBarClearance(self.isTabBarVisible)
    }

    private var goalsMenu: some View {
        Menu {
            Button {
                self.openDestination(.cron)
            } label: {
                Label {
                    Text("Manage automations").font(OpenClawType.body)
                } icon: {
                    Image(systemName: "timer")
                }
            }
            Button {
                Task { await self.sidebarModel.refresh(appModel: self.appModel) }
            } label: {
                Label {
                    Text("Refresh").font(OpenClawType.body)
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SimplePalette.ink)
                .frame(width: SimpleMetric.circleButtonSize, height: SimpleMetric.circleButtonSize)
                .background {
                    Circle()
                        .fill(SimplePalette.surface)
                        .overlay { Circle().stroke(SimplePalette.hairline, lineWidth: 0.5) }
                }
                .simpleFloatingShadow()
        }
        .accessibilityLabel(Text("Goal options"))
        .accessibilityIdentifier("Simple.Goals.Menu")
    }

    // MARK: State

    /// The bar steps aside for the software keyboard so the composer can rise.
    private var isTabBarVisible: Bool {
        !self.isKeyboardVisible
    }

    private var libraryAgentID: String {
        self.appModel.selectedAgentId?.trimmedNonEmpty
            ?? self.appModel.gatewayDefaultAgentId?.trimmedNonEmpty
            ?? "main"
    }

    private var attentionTabs: Set<SimpleTab> {
        self.sidebarModel.failedCronJobCount > 0 ? [.goals] : []
    }

    private var chatsAction: OpenClawSidebarHeaderAction {
        OpenClawSidebarHeaderAction(
            systemName: "line.3.horizontal",
            accessibilityLabel: .localized("Chats"),
            accessibilityIdentifier: "Simple.Chats.Show",
            action: self.openChats)
    }

    // MARK: Actions

    /// Starts an idea or goal in the current chat. A draft the user already
    /// typed is never lost: the prompt is appended below it and left in the
    /// composer for review instead of being sent. Uses the same composer
    /// resolver as the built-in starter prompts, so a detached or stale chat
    /// model is never written to.
    private func startInChat(_ prompt: String) {
        self.selectedTab = .chat
        guard let viewModel = self.appModel.chatPresentation.composerModelResolver()() else { return }
        let draft = viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.isEmpty else {
            viewModel.input = draft + "\n\n" + prompt
            return
        }
        viewModel.input = prompt
        viewModel.send()
    }
}
