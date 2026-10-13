import OpenClawKit
import SwiftUI

// SIMPLE-UI: Views for what the agent proposes (Ideas and Goals tabs) and the
// goals it's working on. Data and gateway calls live in `SimpleProposalsModel`.

/// What the Ideas and Goals tabs can do with proposals and goals; built by
/// `SimpleShell`, which owns the chat and the model.
struct SimpleProposalActions {
    /// Ideas run in chat; goal proposals start as goals.
    let start: (SimpleProposal) -> Void
    let dismiss: (SimpleProposal) -> Void
    /// Asks the agent, in chat, to add proposals of this kind to its file.
    let ask: (SimpleProposalsModel.Kind) -> Void
    /// Returns whether the goal started.
    let startGoal: (String) async -> Bool
    let openGoal: (SimpleSessionGoal) -> Void
    let updateGoal: (SimpleSessionGoal, SimpleSessionGoal.Action) -> Void
}

/// The agent's proposals of one kind, with a way to ask for more.
struct SimpleProposalsSection: View {
    let kind: SimpleProposalsModel.Kind
    let model: SimpleProposalsModel
    let agentName: String?
    let actions: SimpleProposalActions

    var body: some View {
        let proposals = self.kind == .goals ? self.model.goalProposals : self.model.ideaProposals
        VStack(alignment: .leading, spacing: 10) {
            SimpleDotSectionHeader(
                verbatim: self.headerTitle,
                tint: SimplePalette.accent,
                halo: SimplePalette.accentTint)
            ForEach(proposals) { proposal in
                SimpleProposalCard(
                    proposal: proposal,
                    startTitle: self.kind == .goals ? Text("Start goal") : Text("Start"),
                    isBusy: self.model.busyIDs.contains(proposal.id),
                    onStart: { self.actions.start(proposal) },
                    onDismiss: { self.actions.dismiss(proposal) })
            }
            self.footer(isEmpty: proposals.isEmpty)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(self.kind == .goals ? "Simple.Proposals.goals" : "Simple.Proposals.ideas")
    }

    @ViewBuilder
    private func footer(isEmpty: Bool) -> some View {
        if !self.model.isConnected {
            self.note(Text("Connect to your computer to get suggestions from your agent."))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if self.model.proposalsUnreadable {
                    self.note(Text(verbatim: self.unreadableText))
                } else if isEmpty {
                    self.note(Text(verbatim: self.emptyText))
                }
                HStack(spacing: 10) {
                    SimpleCapsuleButton(title: Text(verbatim: self.askTitle(isEmpty: isEmpty)), prominent: isEmpty) {
                        self.actions.ask(self.kind)
                    }
                    .accessibilityHint(Text("Asks in chat"))
                    .accessibilityIdentifier(
                        self.kind == .goals ? "Simple.Proposals.Ask.goals" : "Simple.Proposals.Ask.ideas")
                    if let updatedAt = self.model.proposalsUpdatedAt, !isEmpty {
                        Text(verbatim: Self.updatedText(updatedAt))
                            .font(OpenClawType.footnote)
                            .foregroundStyle(SimplePalette.tertiaryInk)
                    }
                }
                .padding(.horizontal, SimpleMetric.gutter + 4)
            }
        }
    }

    private func note(_ text: Text) -> some View {
        text
            .font(OpenClawType.subhead)
            .foregroundStyle(SimplePalette.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SimpleMetric.gutter + 4)
    }

    // MARK: Copy

    private var name: String {
        self.agentName ?? String(localized: "your agent")
    }

    private var subject: String {
        self.agentName ?? String(localized: "Your agent")
    }

    private var headerTitle: String {
        switch self.kind {
        case .ideas: String(localized: "From \(self.name)")
        case .goals: String(localized: "Suggested by \(self.name)")
        }
    }

    private var emptyText: String {
        switch self.kind {
        case .ideas:
            String(localized: """
            \(self.subject) can suggest things to take off your plate, based on what it knows about you.
            """)
        case .goals:
            String(localized: "\(self.subject) can suggest goals to work toward over the next few weeks.")
        }
    }

    private var unreadableText: String {
        String(localized: "Couldn't read \(SimpleIdeasFile.path). Ask \(self.name) for ideas again to rewrite it.")
    }

    private func askTitle(isEmpty: Bool) -> String {
        switch (self.kind, isEmpty) {
        case (.ideas, true): String(localized: "Get ideas")
        case (.ideas, false): String(localized: "Ask for more ideas")
        case (.goals, true): String(localized: "Get goal ideas")
        case (.goals, false): String(localized: "Ask for more goals")
        }
    }

    private static func updatedText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return String(
            format: String(localized: "Updated %@"),
            formatter.localizedString(for: date, relativeTo: .now))
    }
}

private struct SimpleProposalCard: View {
    let proposal: SimpleProposal
    let startTitle: Text
    let isBusy: Bool
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SimpleIconTile(
                    systemImage: self.proposal.isGoal ? "target" : "sparkles",
                    tint: SimplePalette.accent,
                    size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: self.proposal.title)
                        .font(OpenClawType.headline)
                        .foregroundStyle(SimplePalette.ink)
                    if !self.proposal.summary.isEmpty {
                        Text(verbatim: self.proposal.summary)
                            .font(OpenClawType.subhead)
                            .foregroundStyle(SimplePalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 8) {
                if self.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minHeight: 32)
                } else {
                    SimpleCapsuleButton(title: self.startTitle, prominent: true, action: self.onStart)
                        .accessibilityIdentifier("Simple.Proposal.Start.\(self.proposal.id)")
                    SimpleCapsuleButton(title: Text("Not now"), prominent: false, action: self.onDismiss)
                        .accessibilityIdentifier("Simple.Proposal.Dismiss.\(self.proposal.id)")
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 48)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                .fill(SimplePalette.surface))
        .overlay(
            RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                .stroke(SimplePalette.hairline, lineWidth: 0.5))
        .padding(.horizontal, SimpleMetric.gutter)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Simple.Proposal.\(self.proposal.id)")
    }
}

/// A goal on one of the agent's chats: tap to open that chat; the trailing
/// button pauses or resumes it.
struct SimpleSessionGoalRow: View {
    let goal: SimpleSessionGoal
    let isBusy: Bool
    let onOpen: () -> Void
    let onAction: (SimpleSessionGoal.Action) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: self.onOpen) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: self.goal.status.symbol)
                        .font(.system(size: 21, weight: .regular))
                        .foregroundStyle(self.goal.status.tint)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: self.goal.objective)
                            .font(OpenClawType.body)
                            .foregroundStyle(SimplePalette.ink)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        Text(verbatim: self.statusLine)
                            .font(OpenClawType.subhead)
                            .foregroundStyle(self.goal.status.needsAttention
                                ? SimplePalette.attention
                                : SimplePalette.secondaryInk)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the chat where this goal lives"))
            if self.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .frame(minHeight: 32)
            } else if let primary = self.goal.actions.first, primary != .complete {
                SimpleCapsuleButton(title: primary.title, prominent: false) {
                    self.onAction(primary)
                }
                .accessibilityIdentifier("Simple.WorkingGoal.\(primary.rawValue).\(self.goal.goalID)")
            }
        }
        .padding(.horizontal, SimpleMetric.gutter + 4)
        .padding(.vertical, 12)
        .contextMenu {
            ForEach(self.goal.actions, id: \.self) { action in
                Button {
                    self.onAction(action)
                } label: {
                    Label {
                        action.title.font(OpenClawType.body)
                    } icon: {
                        Image(systemName: action.symbol)
                    }
                }
            }
            Button(action: self.onOpen) {
                Label {
                    Text("Open chat").font(OpenClawType.body)
                } icon: {
                    Image(systemName: "bubble.left")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Simple.WorkingGoal.\(self.goal.goalID)")
    }

    private var statusLine: String {
        guard let note = self.goal.note else { return self.goal.status.label }
        return "\(self.goal.status.label) · \(note)"
    }
}

/// Starts a goal from the user's own words, inline so it needs no sheet.
struct SimpleStartGoalCard: View {
    let agentName: String?
    let isStarting: Bool
    let onStart: (String) async -> Bool

    @State private var objective = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(
                "",
                text: self.$objective,
                prompt: Text(verbatim: self.placeholder)
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.tertiaryInk),
                axis: .vertical)
                .font(OpenClawType.body)
                .foregroundStyle(SimplePalette.ink)
                .lineLimit(2...6)
                .focused(self.$isFocused)
                .accessibilityLabel(Text("New goal"))
                .accessibilityIdentifier("Simple.StartGoal.Field")
            HStack(spacing: 10) {
                Text("It keeps working on it across turns until it's done.")
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if self.isStarting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    SimpleCapsuleButton(title: Text("Start"), prominent: true) {
                        self.isFocused = false
                        let objective = self.objective
                        Task {
                            // A failed start keeps the text so it can be retried.
                            if await self.onStart(objective) { self.objective = "" }
                        }
                    }
                    .disabled(self.objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("Simple.StartGoal.Start")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                .fill(SimplePalette.surface))
        .overlay(
            RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                .stroke(SimplePalette.hairline, lineWidth: 0.5))
        .padding(.horizontal, SimpleMetric.gutter)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Simple.StartGoal")
    }

    private var placeholder: String {
        String(localized: "What should \(self.agentName ?? String(localized: "your agent")) work toward?")
    }
}

/// A small capsule action: filled for the main choice, quiet otherwise.
struct SimpleCapsuleButton: View {
    let title: Text
    let prominent: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: self.action) {
            self.title
                .font(OpenClawType.footnoteSemiBold)
                .foregroundStyle(self.prominent ? Color.white : SimplePalette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .background(Capsule().fill(self.prominent ? SimplePalette.accent : SimplePalette.fill))
                .contentShape(Capsule())
                .opacity(self.isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
    }
}

extension SimpleSessionGoal.Status {
    var label: String {
        switch self {
        case .active: String(localized: "Working on it")
        case .paused: String(localized: "Paused")
        case .blocked: String(localized: "Blocked")
        case .usageLimited: String(localized: "Stopped at a usage limit")
        case .budgetLimited: String(localized: "Used its token budget")
        case .complete: String(localized: "Done")
        case .unknown: String(localized: "Not running")
        }
    }

    var symbol: String {
        switch self {
        case .active: "target"
        case .paused, .unknown: "pause.circle"
        case .blocked, .usageLimited, .budgetLimited: "exclamationmark.triangle"
        case .complete: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .active: SimplePalette.accent
        case .paused, .unknown: SimplePalette.paused
        case .blocked, .usageLimited, .budgetLimited: SimplePalette.attention
        case .complete: SimplePalette.tracking
        }
    }

    var needsAttention: Bool {
        switch self {
        case .blocked, .usageLimited, .budgetLimited: true
        default: false
        }
    }
}

extension SimpleSessionGoal.Action {
    var title: Text {
        switch self {
        case .pause: Text("Pause")
        case .resume: Text("Resume")
        case .complete: Text("Mark done")
        }
    }

    var symbol: String {
        switch self {
        case .pause: "pause"
        case .resume: "play"
        case .complete: "checkmark"
        }
    }
}
