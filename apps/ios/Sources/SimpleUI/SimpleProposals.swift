import Foundation
import Observation
import OpenClawChatUI
import OpenClawKit

// SIMPLE-UI: Ideas and goals the agent proposes, and the goals it's working on.
//
// Proposals live in `ideas.json` in the agent's workspace. Asking for ideas is
// a normal chat request in which the agent writes that file; the Ideas and
// Goals tabs read it back with `agents.workspace.get` (operator.read), so it
// works from any paired phone. (The gateway's own task suggestions can't be
// used: it offers the `suggest_task` tool only to its web and terminal UIs.)
// The phone can't write the workspace, so "Not now" and started ideas are
// remembered on the phone.
//
// Goals are the gateway's session goals: one durable objective per chat,
// started by `chat.send`'s goal intent on a new chat key (admission creates
// the chat) and read from the `goal` field of `sessions.list` rows.

/// One idea or goal the agent proposed.
struct SimpleProposal: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let prompt: String
    let isGoal: Bool
}

/// The `ideas.json` format the agent is asked to write.
struct SimpleIdeasFile: Decodable, Sendable {
    struct Entry: Decodable, Sendable {
        var id: String?
        var kind: String?
        var title: String?
        var summary: String?
        var prompt: String?
    }

    var ideas: [Entry]

    static let path = "ideas.json"

    /// Usable entries in file order. A missing id falls back to the title, so
    /// "Not now" still sticks; a missing prompt falls back to the title too.
    var proposals: [SimpleProposal] {
        self.ideas.compactMap { entry in
            guard let title = entry.title?.trimmedNonEmpty else { return nil }
            return SimpleProposal(
                id: entry.id?.trimmedNonEmpty ?? title.lowercased(),
                title: title,
                summary: entry.summary?.trimmedNonEmpty ?? "",
                prompt: entry.prompt?.trimmedNonEmpty ?? title,
                isGoal: entry.kind?.trimmedNonEmpty?.lowercased() == "goal")
        }
    }
}

/// A goal attached to one of the agent's chats.
struct SimpleSessionGoal: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable {
        case active
        case paused
        case blocked
        case usageLimited = "usage_limited"
        case budgetLimited = "budget_limited"
        case complete
        /// A status this version doesn't know; shown, but offers no actions.
        case unknown
    }

    enum Action: String, Sendable {
        case pause
        case resume
        case complete
    }

    let sessionKey: String
    let goalID: String
    let objective: String
    let status: Status
    let note: String?
    let updatedAt: Date?

    var id: String {
        self.goalID
    }

    var actions: [Action] {
        switch self.status {
        case .active: [.pause, .complete]
        case .paused, .blocked, .usageLimited, .budgetLimited: [.resume, .complete]
        case .complete, .unknown: []
        }
    }

    /// Goals still in play first, then finished ones; newest first within each.
    static func goals(from list: SimpleSessionsGoalsLite) -> [SimpleSessionGoal] {
        list.sessions
            .compactMap { row -> SimpleSessionGoal? in
                guard let goal = row.goal, let objective = goal.objective.trimmedNonEmpty else { return nil }
                return SimpleSessionGoal(
                    sessionKey: row.key,
                    goalID: goal.id,
                    objective: objective,
                    status: Status(rawValue: goal.status) ?? .unknown,
                    note: goal.lastStatusNote?.trimmedNonEmpty,
                    updatedAt: goal.updatedAt.map { Date(timeIntervalSince1970: $0 / 1000) })
            }
            .sorted { lhs, rhs in
                if (lhs.status == .complete) != (rhs.status == .complete) {
                    return rhs.status == .complete
                }
                return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
            }
    }
}

/// The parts of `sessions.list` rows the Goals tab reads.
struct SimpleSessionsGoalsLite: Decodable, Sendable {
    struct Row: Decodable, Sendable {
        struct Goal: Decodable, Sendable {
            var id: String
            var objective: String
            var status: String
            var updatedAt: Double?
            var lastStatusNote: String?
        }

        var key: String
        var goal: Goal?
    }

    var sessions: [Row]
}

/// The parts of `agents.workspace.get` the tabs read.
struct SimpleWorkspaceFileLite: Decodable, Sendable {
    struct File: Decodable, Sendable {
        var updatedAtMs: Int
        var encoding: String
        var content: String
    }

    var file: File

    /// The gateway's answer for a path that doesn't exist, as opposed to a
    /// timeout or another failure.
    static func isMissingFile(_ error: Error) -> Bool {
        (error as? GatewayResponseError)?.details["type"]?.stringValue == "workspace_file_not_found"
    }

    var text: String? {
        guard self.file.encoding == "base64" else { return self.file.content }
        return Data(base64Encoded: self.file.content).flatMap { String(data: $0, encoding: .utf8) }
    }
}

@MainActor
@Observable
final class SimpleProposalsModel {
    enum Kind: Equatable, Sendable {
        case ideas
        case goals
    }

    private(set) var proposals: [SimpleProposal] = []
    /// When the agent last wrote `ideas.json`.
    private(set) var proposalsUpdatedAt: Date?
    /// The file exists but isn't in the expected format.
    private(set) var proposalsUnreadable = false
    private(set) var goals: [SimpleSessionGoal] = []
    private(set) var busyIDs: Set<String> = []
    private(set) var errorMessage: String?
    private(set) var isConnected = true
    private(set) var dismissedIDs: Set<String>

    @ObservationIgnored private var usesSample = false

    private static let dismissedKey = "ui.simpleShell.dismissedProposals"
    private static let dismissedLimit = 300

    init() {
        self.dismissedIDs = Set(UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? [])
    }

    /// True in screenshot and demo modes, where proposals and goals are samples.
    var usesSampleData: Bool {
        self.usesSample
    }

    var ideaProposals: [SimpleProposal] {
        self.proposals.filter { !$0.isGoal && !self.dismissedIDs.contains($0.id) }
    }

    var goalProposals: [SimpleProposal] {
        self.proposals.filter { $0.isGoal && !self.dismissedIDs.contains($0.id) }
    }

    func clearError() {
        self.errorMessage = nil
    }

    func refresh(appModel: NodeAppModel) async {
        if appModel.isScreenshotFixtureModeEnabled || appModel.isAppleReviewDemoModeEnabled {
            self.isConnected = true
            if !self.usesSample {
                self.usesSample = true
                // Demo dismissals stay in memory so they never reach a real gateway's list.
                self.dismissedIDs = []
                self.proposals = SimpleProposalsSample.proposals
                self.proposalsUpdatedAt = Date(timeIntervalSinceNow: -2 * 3600)
                self.goals = SimpleProposalsSample.goals
            }
            return
        }
        if self.usesSample {
            self.usesSample = false
            self.dismissedIDs = Set(UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? [])
            self.proposals = []
            self.proposalsUpdatedAt = nil
            self.goals = []
        }
        self.isConnected = appModel.isOperatorGatewayConnected
        guard self.isConnected else {
            self.proposals = []
            self.goals = []
            return
        }
        async let file = Self.loadProposals(appModel: appModel)
        async let goals = Self.loadGoals(appModel: appModel)
        let loaded = await file
        self.proposalsUnreadable = loaded == .unreadable
        switch loaded {
        case let .loaded(proposals, updatedAt):
            self.proposals = proposals
            self.proposalsUpdatedAt = updatedAt
        case .missing:
            self.proposals = []
            self.proposalsUpdatedAt = nil
        case .unreadable, .failed:
            // Keep what's shown; a failed read says nothing about the file.
            break
        }
        if let goals = await goals { self.goals = goals }
    }

    /// Hides a proposal on this phone; the agent's file is left as it is.
    func dismiss(_ proposal: SimpleProposal) {
        self.dismissedIDs.insert(proposal.id)
        guard !self.usesSample else { return }
        // Newest last, so trimming drops the oldest.
        var stored = UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? []
        stored.removeAll { $0 == proposal.id }
        stored.append(proposal.id)
        UserDefaults.standard.set(Array(stored.suffix(Self.dismissedLimit)), forKey: Self.dismissedKey)
    }

    /// Starts a goal in a new chat, which then holds it, and returns that
    /// chat's key (empty for a sample goal, which has no chat). A proposal it
    /// came from is hidden once the goal starts.
    func startGoal(
        objective: String,
        from proposal: SimpleProposal? = nil,
        appModel: NodeAppModel) async -> String?
    {
        guard let objective = objective.trimmedNonEmpty else { return nil }
        let busyID = proposal?.id ?? "new-goal"
        guard !self.busyIDs.contains(busyID) else { return nil }
        self.busyIDs.insert(busyID)
        defer { self.busyIDs.remove(busyID) }

        if self.usesSample {
            self.goals.insert(
                SimpleSessionGoal(
                    sessionKey: "",
                    goalID: UUID().uuidString,
                    objective: objective,
                    status: .active,
                    note: nil,
                    updatedAt: .now),
                at: 0)
            if let proposal { self.dismiss(proposal) }
            return ""
        }
        do {
            let sessionKey = try await Self.sendGoalStart(objective: objective, appModel: appModel)
            if let proposal { self.dismiss(proposal) }
            if let goals = await Self.loadGoals(appModel: appModel) { self.goals = goals }
            return sessionKey
        } catch {
            self.errorMessage = String(
                format: String(localized: "Couldn't start the goal: %@"),
                error.localizedDescription)
            return nil
        }
    }

    func update(_ goal: SimpleSessionGoal, _ action: SimpleSessionGoal.Action, appModel: NodeAppModel) async {
        guard !self.busyIDs.contains(goal.id) else { return }
        self.busyIDs.insert(goal.id)
        defer { self.busyIDs.remove(goal.id) }
        if self.usesSample {
            self.replace(goal, status: Self.status(after: action))
            return
        }
        let params: [String: AnyCodable] = [
            "sessionKey": AnyCodable(goal.sessionKey),
            "goalId": AnyCodable(goal.goalID),
            "operationId": AnyCodable(UUID().uuidString.lowercased()),
            "issuedAtMs": AnyCodable(Int(Date().timeIntervalSince1970 * 1000)),
            "action": AnyCodable(action.rawValue),
        ]
        do {
            _ = try await appModel.operatorSession.request(
                method: "sessions.goal.update",
                params: params,
                timeoutMs: 15000)
            self.replace(goal, status: Self.status(after: action))
            if let goals = await Self.loadGoals(appModel: appModel) { self.goals = goals }
        } catch {
            self.errorMessage = String(
                format: String(localized: "Couldn't update the goal: %@"),
                error.localizedDescription)
        }
    }

    // MARK: Gateway

    private enum FileLoad: Equatable, Sendable {
        case loaded([SimpleProposal], Date)
        case missing
        case unreadable
        case failed
    }

    private func replace(_ goal: SimpleSessionGoal, status: SimpleSessionGoal.Status) {
        guard let index = self.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        let old = self.goals[index]
        self.goals[index] = SimpleSessionGoal(
            sessionKey: old.sessionKey,
            goalID: old.goalID,
            objective: old.objective,
            status: status,
            note: old.note,
            updatedAt: .now)
    }

    private static func status(after action: SimpleSessionGoal.Action) -> SimpleSessionGoal.Status {
        switch action {
        case .pause: .paused
        case .resume: .active
        case .complete: .complete
        }
    }

    private static func loadProposals(appModel: NodeAppModel) async -> FileLoad {
        let data: Data
        do {
            data = try await appModel.operatorSession.request(
                method: "agents.workspace.get",
                params: [
                    "agentId": AnyCodable(SimpleAgentIdentity.agentID(appModel: appModel)),
                    "path": AnyCodable(SimpleIdeasFile.path),
                ],
                timeoutMs: 12000)
        } catch {
            // Missing until the agent is first asked for ideas.
            return SimpleWorkspaceFileLite.isMissingFile(error) ? .missing : .failed
        }
        guard let file = try? JSONDecoder().decode(SimpleWorkspaceFileLite.self, from: data),
              let text = file.text,
              let ideas = try? JSONDecoder().decode(SimpleIdeasFile.self, from: Data(text.utf8))
        else { return .unreadable }
        return .loaded(ideas.proposals, Date(timeIntervalSince1970: TimeInterval(file.file.updatedAtMs) / 1000))
    }

    private static func loadGoals(appModel: NodeAppModel) async -> [SimpleSessionGoal]? {
        let request = OpenClawChatGatewayRequests.sessionsList(
            limit: 200,
            search: nil,
            archived: false,
            agentID: SimpleAgentIdentity.agentID(appModel: appModel))
        do {
            let data = try await appModel.operatorSession.request(
                method: request.method,
                params: request.params,
                timeoutMs: request.timeoutMs)
            return try SimpleSessionGoal.goals(from: JSONDecoder().decode(SimpleSessionsGoalsLite.self, from: data))
        } catch {
            return nil
        }
    }

    /// Starts the goal on a new chat key; goal admission creates the chat, so
    /// a failed start leaves nothing behind.
    private static func sendGoalStart(objective: String, appModel: NodeAppModel) async throws -> String {
        let agentID = SimpleAgentIdentity.agentID(appModel: appModel)
        let sessionKey = "agent:\(agentID):ios-\(UUID().uuidString.lowercased())"
        let intent: [String: AnyCodable] = [
            "kind": AnyCodable("session-goal-start"),
            "version": AnyCodable(1),
            "issuedAtMs": AnyCodable(Int(Date().timeIntervalSince1970 * 1000)),
        ]
        _ = try await appModel.operatorSession.request(
            method: "chat.send",
            params: [
                "sessionKey": AnyCodable(sessionKey),
                "agentId": AnyCodable(agentID),
                "message": AnyCodable(objective),
                "intent": AnyCodable(intent),
                "idempotencyKey": AnyCodable(UUID().uuidString.lowercased()),
            ],
            timeoutMs: 30000)
        return sessionKey
    }
}

/// What the phone asks the agent when the user wants proposals. Sent in chat,
/// so it reads as a normal request; the agent answers by updating the file.
enum SimpleProposalPrompts {
    static func ask(_ kind: SimpleProposalsModel.Kind) -> String {
        let request = switch kind {
        case .ideas:
            String(localized: """
            Please add 3 to 5 ideas to ideas.json in your workspace: things you could take off my plate, \
            based on what you know about me. Keep the entries already there unless they're out of date.
            """)
        case .goals:
            String(localized: """
            Please add 2 or 3 goals to ideas.json in your workspace: outcomes you could work toward for me \
            over the next few weeks, based on what you know about me. Keep the entries already there unless \
            they're out of date.
            """)
        }
        let format = String(localized: """
        Use this format: {"ideas": [{"id": "short-kebab-id", "kind": "idea" or "goal", "title": "under 60 \
        characters", "summary": "one plain sentence on why it helps", "prompt": "what I'd send you to start \
        it"}]}. For a goal, the prompt states the full objective as one clear outcome. Don't start any of \
        them, and reply with one short line.
        """)
        return request + "\n\n" + format
    }
}

/// Stand-in proposals and goals for screenshot and App Review demo modes,
/// which have no live gateway to ask.
enum SimpleProposalsSample {
    static let proposals: [SimpleProposal] = [
        SimpleProposal(
            id: "sample-school-emails",
            title: "Summarize this week's school emails",
            summary: "Five messages from school arrived this week. I can pull out dates and anything you need to do.",
            prompt: "Summarize this week's emails from school: list dates, deadlines, and anything I need to do.",
            isGoal: false),
        SimpleProposal(
            id: "sample-meal-plan",
            title: "Plan dinners for next week",
            summary: "You asked for quicker weeknight dinners. I can plan five and make a shopping list.",
            prompt: "Plan five quick weeknight dinners for next week and make one combined shopping list.",
            isGoal: false),
        SimpleProposal(
            id: "sample-passport",
            title: "Renew your passport before summer",
            summary: "Your passport expires in August, two weeks after the Lisbon trip. I can start the renewal.",
            prompt: "Help me renew my passport: check the expiry date, list what I need, and draft the form.",
            isGoal: false),
        SimpleProposal(
            id: "sample-goal-10k",
            title: "Run a 10K by September",
            summary: "You've run three times a week since March. A 10K in September is within reach.",
            prompt: "Help me get ready to run a 10K by September: build a plan from my current runs and adjust it.",
            isGoal: true),
        SimpleProposal(
            id: "sample-goal-savings",
            title: "Save $2,000 for the holidays",
            summary: "Setting aside about $70 a week from now gets you there by December.",
            prompt: "Help me save $2,000 for the holidays by December: set a weekly target and keep me on track.",
            isGoal: true),
    ]

    static let goals: [SimpleSessionGoal] = [
        SimpleSessionGoal(
            sessionKey: "sample-lisbon",
            goalID: "sample-goal-lisbon",
            objective: "Plan a long weekend in Lisbon in May",
            status: .active,
            note: "Shortlisted three hotels near Alfama. Checking flights next.",
            updatedAt: Date(timeIntervalSinceNow: -40 * 60)),
        SimpleSessionGoal(
            sessionKey: "sample-inbox",
            goalID: "sample-goal-inbox",
            objective: "Get my inbox under 50 emails",
            status: .paused,
            note: "Waiting for you to choose which newsletters to keep.",
            updatedAt: Date(timeIntervalSinceNow: -26 * 3600)),
        SimpleSessionGoal(
            sessionKey: "sample-dentist",
            goalID: "sample-goal-dentist",
            objective: "Find a dentist for the kids that takes our insurance",
            status: .complete,
            note: "Booked a checkup for June 3.",
            updatedAt: Date(timeIntervalSinceNow: -3 * 86400)),
    ]
}
