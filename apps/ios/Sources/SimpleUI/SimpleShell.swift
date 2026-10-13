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
    let openConnectors: () -> Void
    let useClassicInterface: () -> Void

    @State private var mountedTabs: Set<SimpleTab> = [.chat]
    @State private var isKeyboardVisible = false
    @State private var proposals = SimpleProposalsModel()

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
        #if DEBUG
        .overlay {
            if SimpleApprovalSampleOverlay.isRequested {
                SimpleApprovalSampleOverlay()
            }
        }
        #endif
        .onChange(of: self.selectedTab, initial: true) { _, tab in
            self.mountedTabs.insert(tab)
            if tab == .ideas || tab == .goals {
                Task { await self.proposals.refresh(appModel: self.appModel) }
            }
        }
        .onChange(of: self.appModel.isOperatorGatewayConnected) { _, _ in
            Task { await self.proposals.refresh(appModel: self.appModel) }
        }
        .alert(Text("Something went wrong"), isPresented: self.showsProposalError) {
            Button(role: .cancel) {} label: {
                Text("OK").font(OpenClawType.subheadSemiBold)
            }
        } message: {
            Text(verbatim: self.proposals.errorMessage ?? "")
                .font(OpenClawType.subhead)
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

    /// A failed goal start or update, shown once and then cleared.
    private var showsProposalError: Binding<Bool> {
        Binding(
            get: { self.proposals.errorMessage != nil },
            set: { if !$0 { self.proposals.clearError() } })
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
                    SimpleIdeasScreen(
                        ideas: SimpleIdeaCatalog.starter,
                        proposals: self.proposals,
                        agentName: SimpleAgentIdentity.givenName(appModel: self.appModel),
                        actions: self.proposalActions)
                    { idea in
                        self.startInChat(idea.prompt)
                    }
                    .refreshable {
                        await self.proposals.refresh(appModel: self.appModel)
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
                        openConnectors: self.openConnectors,
                        useClassicInterface: self.useClassicInterface)
                }
            }
        }
    }

    private var goalsScreen: some View {
        SimpleGoalsScreen(
            jobs: SimpleAgentIdentity.jobs(self.sidebarModel.cronJobs, appModel: self.appModel),
            proposals: self.proposals,
            agentName: SimpleAgentIdentity.givenName(appModel: self.appModel),
            actions: self.proposalActions,
            onOpenJob: { _ in self.openDestination(.cron) },
            onCreate: { template in self.startInChat(template.prompt) })
            .refreshable {
                await self.sidebarModel.refresh(appModel: self.appModel)
                await self.proposals.refresh(appModel: self.appModel)
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

    /// Goals only flags this agent's failing automations, the ones it lists.
    private var attentionTabs: Set<SimpleTab> {
        let jobs = SimpleAgentIdentity.jobs(self.sidebarModel.cronJobs, appModel: self.appModel)
        return jobs.contains { RootSidebarModel.isFailedCronJob($0) } ? [.goals] : []
    }

    private var chatsAction: OpenClawSidebarHeaderAction {
        OpenClawSidebarHeaderAction(
            systemName: "line.3.horizontal",
            accessibilityLabel: .localized("Chats"),
            accessibilityIdentifier: "Simple.Chats.Show",
            action: self.openChats)
    }

    // MARK: Actions

    private var proposalActions: SimpleProposalActions {
        SimpleProposalActions(
            start: { proposal in
                if proposal.isGoal {
                    Task { await self.startGoal(proposal.prompt, from: proposal) }
                } else if self.startInChat(proposal.prompt) {
                    // Only a sent idea is done; one left in the composer keeps its card.
                    self.proposals.dismiss(proposal)
                }
            },
            dismiss: { proposal in
                self.proposals.dismiss(proposal)
            },
            ask: { kind in
                _ = self.startInChat(SimpleProposalPrompts.ask(kind))
            },
            startGoal: { objective in
                await self.startGoal(objective, from: nil)
            },
            openGoal: { goal in
                // Sample goals (screenshot and demo modes) have no chat of their own.
                guard !goal.sessionKey.isEmpty, !self.proposals.usesSampleData else {
                    self.selectedTab = .chat
                    return
                }
                self.appModel.openChat(sessionKey: goal.sessionKey)
            },
            updateGoal: { goal, action in
                Task { await self.proposals.update(goal, action, appModel: self.appModel) }
            })
    }

    /// Starts a goal in its own new chat and opens that chat. Returns whether
    /// it started.
    @discardableResult
    private func startGoal(_ objective: String, from proposal: SimpleProposal?) async -> Bool {
        guard let sessionKey = await self.proposals.startGoal(
            objective: objective,
            from: proposal,
            appModel: self.appModel)
        else { return false }
        if !sessionKey.isEmpty {
            self.appModel.openChat(sessionKey: sessionKey)
        }
        return true
    }

    /// Starts an idea, a planning template, or a request for proposals in the
    /// current chat, or the main chat when the current one holds a goal. A
    /// draft the user already typed is never lost: the prompt is appended
    /// below it and left in the composer for review instead of being sent.
    /// Uses the same composer resolver as the built-in starter prompts, so a
    /// detached or stale chat model is never written to. Returns whether the
    /// prompt was sent; it stays in the composer while a reply is still running.
    @discardableResult
    private func startInChat(_ prompt: String) -> Bool {
        self.selectedTab = .chat
        let currentKey = self.appModel.chatSessionKey
        if self.proposals.goals.contains(where: { !$0.sessionKey.isEmpty && $0.sessionKey == currentKey }) {
            self.appModel.openChat(sessionKey: nil)
            self.appModel.chatPresentation.sync(appModel: self.appModel)
        }
        guard let viewModel = self.appModel.chatPresentation.composerModelResolver()() else { return false }
        let draft = viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.isEmpty else {
            viewModel.input = draft + "\n\n" + prompt
            return false
        }
        viewModel.input = prompt
        return viewModel.send() != nil
    }
}
