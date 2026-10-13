import Foundation
import Observation
import OpenClawKit

// SIMPLE-UI: Data for the profile sheet's tabs.
// - Activity: the gateway's audit feed (`audit.activity.list`, operator.read,
//   newest first, 30 days), finished tool actions in plain language.
// - Permissions: standing "always allow" grants on automations
//   (`exec.approval.grants.list` / `.revoke`, operator.approvals).
// - Upcoming: the automations RootSidebarModel already loads.
// - Memory: `MEMORY.md` in the agent's workspace (`agents.workspace.get`).

/// One line of the Activity tab: what the agent did, merged with repeats
/// from the same run ("Read files · 4 times").
struct SimpleActivityItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let failed: Bool
    let count: Int
    let occurredAt: Date
}

/// The parts of `audit.activity.list` the Activity tab reads.
struct SimpleAuditActivityLite: Decodable, Sendable {
    struct Event: Decodable, Sendable {
        var eventId: String
        var occurredAt: Double
        var action: String?
        var status: String?
        var toolName: String?
        var runId: String?
    }

    var events: [Event]

    /// Finished tool actions, newest first, with back-to-back repeats in one
    /// run folded together.
    var items: [SimpleActivityItem] {
        var items: [SimpleActivityItem] = []
        var lastRun: String?
        for event in self.events where event.action == "tool.action.finished" {
            let rawName = event.toolName?.trimmedNonEmpty ?? "tool"
            let title = SimpleToolVocabulary.title(
                rawName: rawName,
                displayName: rawName.replacingOccurrences(of: "_", with: " "),
                isRunning: false)
            let failed = event.status != "succeeded"
            if let last = items.last, last.title == title, last.failed == failed, lastRun == event.runId {
                items[items.count - 1] = SimpleActivityItem(
                    id: last.id,
                    title: last.title,
                    failed: failed,
                    count: last.count + 1,
                    occurredAt: last.occurredAt)
            } else {
                items.append(SimpleActivityItem(
                    id: event.eventId,
                    title: title,
                    failed: failed,
                    count: 1,
                    occurredAt: Date(timeIntervalSince1970: event.occurredAt / 1000)))
            }
            lastRun = event.runId
        }
        return items
    }
}

/// A command an automation may run without asking.
struct SimpleStandingGrant: Identifiable, Equatable, Sendable {
    let id: String
    let automation: String?
    let command: String
    let useCount: Int
    let lastUsedAt: Date?
    let expiresAt: Date?
}

/// The parts of `exec.approval.grants.list` the Permissions tab reads.
struct SimpleGrantsLite: Decodable, Sendable {
    struct Grant: Decodable, Sendable {
        var grantId: String
        var agentId: String
        var cronJobName: String?
        var command: String
        var expiresAtMs: Double?
        var revokedAtMs: Double?
        var lastUsedAtMs: Double?
        var useCount: Int
    }

    var grants: [Grant]

    /// Live grants for one agent, most used first.
    func active(agentID: String, now: Date = .now) -> [SimpleStandingGrant] {
        let nowMs = now.timeIntervalSince1970 * 1000
        return self.grants
            .filter { grant in
                grant.agentId.lowercased() == agentID && grant.revokedAtMs == nil
                    && (grant.expiresAtMs.map { $0 > nowMs } ?? true)
            }
            .sorted { $0.useCount > $1.useCount }
            .map { grant in
                SimpleStandingGrant(
                    id: grant.grantId,
                    automation: grant.cronJobName?.trimmedNonEmpty,
                    command: grant.command,
                    useCount: grant.useCount,
                    lastUsedAt: grant.lastUsedAtMs.map { Date(timeIntervalSince1970: $0 / 1000) },
                    expiresAt: grant.expiresAtMs.map { Date(timeIntervalSince1970: $0 / 1000) })
            }
    }
}

/// `MEMORY.md` split into what the Memory tab draws: headings, bullets, and
/// paragraphs. Inline Markdown inside each block is left for the view.
enum SimpleMemoryBlock: Equatable, Sendable {
    case heading(String)
    case bullet(String)
    case paragraph(String)

    static let path = "MEMORY.md"

    static func blocks(from markdown: String) -> [SimpleMemoryBlock] {
        var blocks: [SimpleMemoryBlock] = []
        var paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty {
                // Keep line breaks: memory files often use one fact per line.
                blocks.append(.paragraph(paragraph.joined(separator: "\n")))
                paragraph = []
            }
        }
        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) {
                flush()
            } else if line.hasPrefix("#") {
                flush()
                let text = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { blocks.append(.heading(text)) }
            } else if let bullet = Self.bulletText(line) {
                flush()
                blocks.append(.bullet(bullet))
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    private static func bulletText(_ line: String) -> String? {
        for marker in ["- [ ] ", "- [x] ", "- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmedNonEmpty
        }
        return nil
    }
}

@MainActor
@Observable
final class SimpleProfileModel {
    enum Load<Value: Equatable & Sendable>: Equatable, Sendable {
        case loading
        case loaded(Value)
        case unavailable(String)
    }

    private(set) var activity: Load<[SimpleActivityItem]> = .loading
    private(set) var grants: Load<[SimpleStandingGrant]> = .loading
    private(set) var memory: Load<[SimpleMemoryBlock]> = .loading
    private(set) var revokingIDs: Set<String> = []
    private(set) var errorMessage: String?

    @ObservationIgnored private var usesSample = false

    func clearError() {
        self.errorMessage = nil
    }

    func refresh(appModel: NodeAppModel) async {
        if appModel.isScreenshotFixtureModeEnabled || appModel.isAppleReviewDemoModeEnabled {
            self.usesSample = true
            self.activity = .loaded(SimpleProfileSample.activity)
            self.grants = .loaded(SimpleProfileSample.grants)
            self.memory = .loaded(SimpleMemoryBlock.blocks(from: SimpleProfileSample.memory))
            return
        }
        self.usesSample = false
        guard appModel.isOperatorGatewayConnected else {
            let message = String(localized: "Connect to your computer to see this.")
            self.activity = .unavailable(message)
            self.grants = .unavailable(message)
            self.memory = .unavailable(message)
            return
        }
        let agentID = SimpleAgentIdentity.agentID(appModel: appModel)
        async let activity = Self.loadActivity(appModel: appModel, agentID: agentID)
        async let grants = Self.loadGrants(appModel: appModel, agentID: agentID)
        async let memory = Self.loadMemory(appModel: appModel, agentID: agentID)
        self.activity = await activity
        self.grants = await grants
        self.memory = await memory
    }

    func revoke(_ grant: SimpleStandingGrant, appModel: NodeAppModel) async {
        guard !self.revokingIDs.contains(grant.id), case .loaded = self.grants else { return }
        self.revokingIDs.insert(grant.id)
        defer { self.revokingIDs.remove(grant.id) }
        if !self.usesSample {
            do {
                _ = try await appModel.operatorSession.request(
                    method: "exec.approval.grants.revoke",
                    params: ["grantId": AnyCodable(grant.id)],
                    timeoutMs: 15000)
            } catch {
                self.errorMessage = String(
                    format: String(localized: "Couldn't remove the permission: %@"),
                    error.localizedDescription)
                return
            }
        }
        // Read the list again: another removal may have finished meanwhile.
        if case let .loaded(current) = self.grants {
            self.grants = .loaded(current.filter { $0.id != grant.id })
        }
    }

    // MARK: Gateway

    private static func loadActivity(appModel: NodeAppModel, agentID: String) async -> Load<[SimpleActivityItem]> {
        do {
            let data = try await appModel.operatorSession.request(
                method: "audit.activity.list",
                params: [
                    "agentId": AnyCodable(agentID),
                    "kind": AnyCodable("tool_action"),
                    "limit": AnyCodable(200),
                ],
                timeoutMs: 15000)
            return try .loaded(JSONDecoder().decode(SimpleAuditActivityLite.self, from: data).items)
        } catch {
            return .unavailable(String(localized: "Couldn't load activity. Pull down to try again."))
        }
    }

    private static func loadGrants(appModel: NodeAppModel, agentID: String) async -> Load<[SimpleStandingGrant]> {
        do {
            let data = try await appModel.operatorSession.request(
                method: "exec.approval.grants.list",
                params: ["limit": AnyCodable(200)],
                timeoutMs: 15000)
            return try .loaded(JSONDecoder().decode(SimpleGrantsLite.self, from: data).active(agentID: agentID))
        } catch {
            return .unavailable(String(localized: """
            Couldn't load permissions. This iPhone may need approvals access, which it gets when it's \
            paired to handle approvals.
            """))
        }
    }

    private static func loadMemory(appModel: NodeAppModel, agentID: String) async -> Load<[SimpleMemoryBlock]> {
        let data: Data
        do {
            data = try await appModel.operatorSession.request(
                method: "agents.workspace.get",
                params: ["agentId": AnyCodable(agentID), "path": AnyCodable(SimpleMemoryBlock.path)],
                timeoutMs: 12000)
        } catch {
            guard SimpleWorkspaceFileLite.isMissingFile(error) else {
                return .unavailable(String(localized: "Couldn't load memory. Pull down to try again."))
            }
            return .loaded([])
        }
        guard let text = (try? JSONDecoder().decode(SimpleWorkspaceFileLite.self, from: data))?.text else {
            return .unavailable(String(localized: "Couldn't read the memory file."))
        }
        return .loaded(SimpleMemoryBlock.blocks(from: text))
    }
}

/// Stand-in data for screenshot and App Review demo modes.
enum SimpleProfileSample {
    static let activity: [SimpleActivityItem] = [
        SimpleActivityItem(
            id: "a1",
            title: "Browsed the web",
            failed: false,
            count: 3,
            occurredAt: Date(timeIntervalSinceNow: -12 * 60)),
        SimpleActivityItem(
            id: "a2",
            title: "Checked your calendar",
            failed: false,
            count: 1,
            occurredAt: Date(timeIntervalSinceNow: -50 * 60)),
        SimpleActivityItem(
            id: "a3",
            title: "Sent a message",
            failed: false,
            count: 1,
            occurredAt: Date(timeIntervalSinceNow: -2 * 3600)),
        SimpleActivityItem(
            id: "a4",
            title: "Ran a command",
            failed: true,
            count: 1,
            occurredAt: Date(timeIntervalSinceNow: -5 * 3600)),
        SimpleActivityItem(
            id: "a5",
            title: "Updated memory",
            failed: false,
            count: 2,
            occurredAt: Date(timeIntervalSinceNow: -26 * 3600)),
        SimpleActivityItem(
            id: "a6",
            title: "Read files",
            failed: false,
            count: 4,
            occurredAt: Date(timeIntervalSinceNow: -28 * 3600)),
    ]

    static let grants: [SimpleStandingGrant] = [
        SimpleStandingGrant(
            id: "g1",
            automation: "Morning briefing",
            command: "curl -s wttr.in/Lisbon?format=3",
            useCount: 18,
            lastUsedAt: Date(timeIntervalSinceNow: -6 * 3600),
            expiresAt: nil),
        SimpleStandingGrant(
            id: "g2",
            automation: "Weekly backup check",
            command: "tmutil latestbackup",
            useCount: 4,
            lastUsedAt: Date(timeIntervalSinceNow: -3 * 86400),
            expiresAt: Date(timeIntervalSinceNow: 20 * 86400)),
    ]

    static let memory = """
    # About you
    - Lives in Porto with Sam and two kids, Ana (9) and Leo (6).
    - Prefers short **morning briefings** before 8 AM.
    - Runs three times a week; training for a 10K.

    # Work
    Product designer. Deep-work blocks on Tuesday and Thursday mornings; keep them free.

    # Preferences
    - Vegetarian weeknight dinners, 30 minutes or less.
    - Book flights with a window seat.
    """
}
