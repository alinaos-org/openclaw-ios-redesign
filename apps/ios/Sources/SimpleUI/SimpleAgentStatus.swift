import OpenClawChatUI
import OpenClawKit
import OpenClawProtocol
import SwiftUI

// SIMPLE-UI: Plain-language "what is my agent doing" summary, shown under the
// agent's name in the header ("Browsing the web…") and driving the mascot's
// mood. Derived only from state the app already observes, so it costs
// nothing extra on the wire.

struct SimpleAgentStatus: Equatable {
    enum Phase: Equatable {
        case idle
        case offline
        case needsApproval
        case listening
        case speaking
        case thinking
        case usingTool
        case writing
    }

    let phase: Phase
    let text: String?

    static let idle = SimpleAgentStatus(phase: .idle, text: nil)

    var isWorking: Bool {
        switch self.phase {
        case .thinking, .usingTool, .writing: true
        default: false
        }
    }

    var mood: OpenClawMascotMood {
        switch self.phase {
        case .idle: .idle
        case .offline: .sleepy
        case .needsApproval: .curious
        case .listening: .attentive
        case .speaking: .happy
        case .thinking, .writing: .thinking
        case .usingTool: .working
        }
    }

    @MainActor
    static func resolve(appModel: NodeAppModel) -> SimpleAgentStatus {
        if appModel.pendingExecApprovalPrompt != nil {
            return SimpleAgentStatus(phase: .needsApproval, text: String(localized: "Waiting for your OK"))
        }
        let talk = appModel.talkMode
        if talk.isEnabled {
            if talk.isSpeaking {
                return SimpleAgentStatus(phase: .speaking, text: String(localized: "Talking…"))
            }
            if talk.isListening {
                return SimpleAgentStatus(phase: .listening, text: String(localized: "Listening…"))
            }
        }
        let canChat = appModel.isOperatorGatewayConnected
            || appModel.isLocalChatFixtureEnabled
            || appModel.isAppleReviewDemoModeEnabled
        guard canChat else {
            return SimpleAgentStatus(phase: .offline, text: String(localized: "Offline"))
        }
        guard let viewModel = appModel.chatPresentation.viewModel else { return .idle }
        if let call = viewModel.pendingToolCalls.first {
            let displayName = ToolDisplayRegistry.displayCall(name: call.name, args: call.args).name ?? call.name
            return SimpleAgentStatus(
                phase: .usingTool,
                text: Self.toolPhrase(rawName: call.name, displayName: displayName))
        }
        if viewModel.streamingAssistantText != nil {
            return SimpleAgentStatus(phase: .writing, text: String(localized: "Writing…"))
        }
        if viewModel.pendingRunCount > 0 || viewModel.isSending {
            return SimpleAgentStatus(phase: .thinking, text: String(localized: "Thinking…"))
        }
        return .idle
    }

    /// Friendly verb for a running tool call, for the header's status line.
    static func toolPhrase(rawName: String, displayName: String) -> String {
        SimpleToolVocabulary.title(rawName: rawName, displayName: displayName, isRunning: true)
    }
}

/// Plain-language names for tool calls, in progress ("Running a command…")
/// and finished ("Ran a command"). Gateway tool names are developer-facing
/// (`web_fetch`, `exec`, `sessions_spawn`); the simple layout speaks in outcomes.
enum SimpleToolVocabulary {
    struct Phrase: Equatable {
        let running: String
        let done: String
    }

    static func title(rawName: String, displayName: String, isRunning: Bool) -> String {
        if let phrase = self.phrase(rawName: rawName, displayName: displayName) {
            return isRunning ? phrase.running : phrase.done
        }
        let readable = displayName.replacingOccurrences(of: "_", with: " ")
        return isRunning
            ? String(format: String(localized: "Using %@…"), readable)
            : String(format: String(localized: "Used %@"), readable)
    }

    /// Matching is per word, across both the raw and display names, so
    /// wrapper tools still resolve and "thread" never reads as "read".
    static func phrase(rawName: String, displayName: String) -> Phrase? {
        let words = "\(rawName) \(displayName)"
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        func has(_ prefixes: String...) -> Bool {
            words.contains { word in prefixes.contains { word.hasPrefix($0) } }
        }
        func make(_ running: String.LocalizationValue, _ done: String.LocalizationValue) -> Phrase {
            Phrase(running: String(localized: running), done: String(localized: done))
        }
        if has("browser") { return make("Browsing the web…", "Browsed the web") }
        if has("search") { return make("Searching…", "Searched") }
        if has("fetch") { return make("Reading a web page…", "Read a web page") }
        if has("calendar") { return make("Checking your calendar…", "Checked your calendar") }
        if has("reminder") { return make("Checking your reminders…", "Checked your reminders") }
        if has("contact") { return make("Looking up contacts…", "Looked up contacts") }
        if has("location") { return make("Checking your location…", "Checked your location") }
        if has("camera", "image", "photo", "screen") { return make("Looking at an image…", "Looked at an image") }
        if has("memory") { return make("Updating memory…", "Updated memory") }
        if has("cron", "schedule") { return make("Scheduling…", "Scheduled a check-in") }
        if has("message", "send", "notify") { return make("Sending a message…", "Sent a message") }
        if has("spawn", "subagent") { return make("Asking a helper…", "Asked a helper") }
        if has("write", "edit", "patch") { return make("Editing files…", "Edited files") }
        if has("read", "file") { return make("Reading files…", "Read files") }
        if has("exec", "bash", "shell", "process", "command") { return make("Running a command…", "Ran a command") }
        return nil
    }
}

/// The agent's display name, resolved the same way the chat header does.
enum SimpleAgentIdentity {
    @MainActor
    static func displayName(appModel: NodeAppModel) -> String {
        self.givenName(appModel: appModel) ?? appModel.chatAgentName
    }

    /// The chat's agent id, normalized the way the gateway stores agent ids.
    @MainActor
    static func agentID(appModel: NodeAppModel) -> String {
        (appModel.chatAgentId.trimmedNonEmpty ?? appModel.gatewayDefaultAgentId?.trimmedNonEmpty ?? "main")
            .lowercased()
    }

    /// The chat agent's automations, for Goals and the profile's Upcoming tab.
    @MainActor
    static func jobs(_ jobs: [CronJob], appModel: NodeAppModel) -> [CronJob] {
        let agentID = self.agentID(appModel: appModel)
        let defaultAgentID = appModel.gatewayDefaultAgentId?.trimmedNonEmpty?.lowercased() ?? "main"
        return jobs.filter {
            self.owns(jobAgentID: $0.agentid, agentID: agentID, defaultAgentID: defaultAgentID)
        }
    }

    /// Whether a job belongs to `agentID`; a job without an agent runs on the
    /// gateway's default agent.
    static func owns(jobAgentID: String?, agentID: String, defaultAgentID: String) -> Bool {
        (jobAgentID?.trimmedNonEmpty?.lowercased() ?? defaultAgentID) == agentID
    }

    /// The name the agent was given on the gateway; nil when only its id is
    /// known, so copy can say "your agent" instead of "Main".
    @MainActor
    static func givenName(appModel: NodeAppModel) -> String? {
        let agentID = appModel.chatAgentId.trimmedNonEmpty ?? "main"
        return appModel.gatewayAgents.first { $0.id == agentID }?.name?.trimmedNonEmpty
    }
}
