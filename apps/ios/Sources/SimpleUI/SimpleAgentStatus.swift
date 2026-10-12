import OpenClawChatUI
import OpenClawKit
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

    /// Friendly verb for a tool call. Gateway tool names are developer-facing
    /// (`web_fetch`, `exec`, `sessions_spawn`); the header speaks in outcomes.
    /// Matching is per word, across both the raw and display names, so
    /// wrapper tools still resolve and "thread" never reads as "read".
    static func toolPhrase(rawName: String, displayName: String) -> String {
        let words = "\(rawName) \(displayName)"
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        func has(_ prefixes: String...) -> Bool {
            words.contains { word in prefixes.contains { word.hasPrefix($0) } }
        }
        if has("browser") { return String(localized: "Browsing the web…") }
        if has("search") { return String(localized: "Searching…") }
        if has("fetch") { return String(localized: "Reading a web page…") }
        if has("calendar") { return String(localized: "Checking your calendar…") }
        if has("reminder") { return String(localized: "Checking your reminders…") }
        if has("contact") { return String(localized: "Looking up contacts…") }
        if has("location") { return String(localized: "Checking your location…") }
        if has("camera", "image", "photo", "screen") { return String(localized: "Looking at an image…") }
        if has("memory") { return String(localized: "Updating memory…") }
        if has("cron", "schedule") { return String(localized: "Scheduling…") }
        if has("message", "send", "notify") { return String(localized: "Sending a message…") }
        if has("spawn", "subagent") { return String(localized: "Asking a helper…") }
        if has("read", "write", "edit", "patch", "file") { return String(localized: "Working on files…") }
        if has("exec", "bash", "shell", "process", "command") { return String(localized: "Running a task…") }
        let readable = displayName.replacingOccurrences(of: "_", with: " ")
        return String(format: String(localized: "Using %@…"), readable)
    }
}

/// The agent's display name, resolved the same way the chat header does.
enum SimpleAgentIdentity {
    @MainActor
    static func displayName(appModel: NodeAppModel) -> String {
        let agentID = appModel.chatAgentId.trimmedNonEmpty ?? "main"
        let agent = appModel.gatewayAgents.first { $0.id == agentID }
        return agent?.name?.trimmedNonEmpty ?? appModel.chatAgentName
    }
}
