import CoreLocation
import Foundation
import Observation
import OpenClawChatUI
import OpenClawKit
import Photos

// SIMPLE-UI: Data for the Connectors sheet: what the agent can reach on this
// iPhone (iOS permissions plus OpenClaw's own camera and location switches),
// the gateway's messaging apps (`channels.status`), and the agent's skills
// (`skills.status`). Both gateway calls need only operator.read, so every
// paired phone can show them. Permission requests go through the owners the
// device settings page uses, followed by the same registration refresh.

/// One iPhone feature the agent can use.
struct SimplePhoneFeature: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case calendar
        case reminders
        case contacts
        case photos
        case camera
        case microphone
        case location
    }

    enum State: Equatable {
        /// Usable by the agent; the detail qualifies it ("While using the app").
        case on(detail: String?)
        /// iOS hasn't asked yet; turning it on shows the system prompt.
        case askable
        /// iOS allows it, but OpenClaw's own switch is off.
        case offInApp
        /// Only the Settings app can change it; the detail says why.
        case blocked(detail: String)
        case unavailable
    }

    let kind: Kind
    let state: State

    var id: Kind {
        self.kind
    }

    /// Combines iOS permission status with OpenClaw's camera and location
    /// switches, which gate what the phone advertises to the gateway.
    static func features(
        statuses: [DeviceSettingsPermission: DeviceSettingsPermissionStatus],
        cameraEnabled: Bool,
        locationMode: OpenClawLocationMode,
        locationAuthorization: CLAuthorizationStatus) -> [SimplePhoneFeature]
    {
        Kind.allCases.map { kind in
            let status = statuses[kind.permission] ?? .unavailable
            return SimplePhoneFeature(kind: kind, state: Self.state(
                kind: kind,
                status: status,
                cameraEnabled: cameraEnabled,
                locationMode: locationMode,
                locationAuthorization: locationAuthorization))
        }
    }

    private static func state(
        kind: Kind,
        status: DeviceSettingsPermissionStatus,
        cameraEnabled: Bool,
        locationMode: OpenClawLocationMode,
        locationAuthorization: CLAuthorizationStatus) -> State
    {
        switch status {
        case .notDetermined:
            // Location's switch requests the permission itself.
            return .askable
        case .denied:
            return .blocked(detail: String(localized: "Off in iPhone Settings"))
        case .unavailable:
            return .unavailable
        case .limited where kind == .calendar || kind == .reminders:
            // "Add Events Only": the phone doesn't advertise these as readable.
            return .blocked(detail: String(localized: "Can add but not see"))
        case .granted, .limited:
            let limited = status == .limited ? String(localized: "Limited access") : nil
            switch kind {
            case .camera:
                return cameraEnabled ? .on(detail: limited) : .offInApp
            case .location:
                switch locationMode {
                case .off:
                    return .offInApp
                case .always where locationAuthorization == .authorizedAlways:
                    return .on(detail: String(localized: "Always"))
                case .whileUsing, .always:
                    // Always mode with While Using permission still works in the foreground.
                    return .on(detail: String(localized: "While using the app"))
                }
            default:
                return .on(detail: limited)
            }
        }
    }
}

extension SimplePhoneFeature.Kind {
    var permission: DeviceSettingsPermission {
        switch self {
        case .calendar: .calendars
        case .reminders: .reminders
        case .contacts: .contacts
        case .photos: .photos
        case .camera: .camera
        case .microphone: .microphone
        case .location: .location
        }
    }
}

/// A messaging app the gateway knows about, reduced to what the overview shows.
struct SimpleMessagingApp: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable {
        case connected
        case attention(String)
        /// Set up on the gateway but not running.
        case off
        case notSetUp
    }

    let id: String
    let name: String
    let systemImage: String?
    let state: State

    var isSetUp: Bool {
        self.state != .notSetUp
    }

    static func apps(from status: SimpleChannelsStatusLite) -> [SimpleMessagingApp] {
        let apps = status.channelOrder.map { id in
            SimpleMessagingApp(
                id: id,
                name: status.channelLabels[id] ?? id.capitalized,
                systemImage: status.channelSystemImages?[id],
                state: Self.state(
                    accounts: status.channelAccounts?[id] ?? [],
                    issue: status.statusIssues?.first { $0.channel == id }))
        }
        // Apps in use first, each group in the gateway's order.
        return apps.filter(\.isSetUp) + apps.filter { !$0.isSetUp }
    }

    private static func state(
        accounts: [SimpleChannelsStatusLite.Account],
        issue: SimpleChannelsStatusLite.Issue?) -> State
    {
        if let issue { return .attention(issue.message) }
        let active = accounts.filter { $0.enabled != false }
        if active.contains(where: { $0.connected == true || ($0.connected == nil && $0.running == true) }) {
            return .connected
        }
        if let error = active.compactMap(\.lastError).first(where: { !$0.isEmpty }) {
            return .attention(error)
        }
        if active.contains(where: { $0.running == true }) {
            return .attention(String(localized: "Reconnecting…"))
        }
        if accounts.contains(where: { $0.configured == true }) {
            return .off
        }
        return .notSetUp
    }
}

/// The parts of `channels.status` the overview reads. The gateway keeps
/// account snapshots schema-light, so every account field is optional.
struct SimpleChannelsStatusLite: Decodable, Equatable {
    struct Account: Decodable, Equatable {
        var enabled: Bool?
        var configured: Bool?
        var running: Bool?
        var connected: Bool?
        var lastError: String?
    }

    struct Issue: Decodable, Equatable {
        var channel: String
        var message: String
    }

    var channelOrder: [String]
    var channelLabels: [String: String]
    var channelSystemImages: [String: String]?
    var channelAccounts: [String: [Account]]?
    var statusIssues: [Issue]?
}

/// A skill the agent has, ready or waiting on setup.
struct SimpleSkill: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable {
        case ready
        case needsSetup(String)
    }

    let id: String
    let name: String
    let emoji: String?
    let summary: String
    let state: State

    /// Skills the agent can use or could with setup. Turned-off, blocked, and
    /// incompatible skills are left out: nothing on this phone changes them.
    static func skills(from report: SkillsStatusReport) -> [SimpleSkill] {
        report.skills
            .filter {
                !$0.disabled && $0.blockedByAllowlist != true && $0.blockedByAgentFilter != true
                    && $0.platformIncompatible != true
            }
            .map { skill in
                SimpleSkill(
                    id: skill.skillKey,
                    name: Self.displayName(skill.name),
                    emoji: skill.emoji,
                    summary: skill.description,
                    state: skill.eligible ? .ready : .needsSetup(Self.missingSummary(skill.missing)))
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// "apple-notes" → "Apple Notes", "gh-issues" → "GitHub Issues".
    static func displayName(_ name: String) -> String {
        name.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { word in
                Self.brandSpellings[word.lowercased()] ?? word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    /// Words skill ids spell differently from their product names, drawn from
    /// upstream's bundled skills.
    private static let brandSpellings: [String: String] = [
        "1password": "1Password",
        "ai": "AI",
        "api": "API",
        "clawhub": "ClawHub",
        "cli": "CLI",
        "gh": "GitHub",
        "gif": "GIF",
        "github": "GitHub",
        "imessage": "iMessage",
        "ios": "iOS",
        "llm": "LLM",
        "macos": "macOS",
        "mcp": "MCP",
        "onnx": "ONNX",
        "openai": "OpenAI",
        "openhue": "OpenHue",
        "pdf": "PDF",
        "tmux": "tmux",
        "tts": "TTS",
        "ui": "UI",
        "url": "URL",
        "youtube": "YouTube",
    ]

    static func missingSummary(_ missing: SkillMissing) -> String {
        if let bin = missing.bins.first ?? missing.anyBins.first {
            return String(format: String(localized: "Needs %@ installed on your computer"), bin)
        }
        if let key = missing.env.first {
            return String(format: String(localized: "Needs %@ set on your computer"), key)
        }
        if !missing.config.isEmpty {
            return String(localized: "Needs a setting turned on")
        }
        return String(localized: "Needs setup on your computer")
    }
}

@MainActor
@Observable
final class SimpleConnectorsModel {
    /// Sendable so the two gateway loads can run side by side (`async let`).
    enum Load<Value: Equatable & Sendable>: Equatable, Sendable {
        case loading
        case loaded(Value)
        case unavailable(String)
    }

    private(set) var phone: [SimplePhoneFeature] = []
    private(set) var messaging: Load<[SimpleMessagingApp]> = .loading
    private(set) var skills: Load<[SimpleSkill]> = .loading
    private(set) var busyFeature: SimplePhoneFeature.Kind?

    /// Created on first use: it owns an `EKEventStore`, which is costly, and
    /// SwiftUI may build this model more than once while the sheet is shown.
    @ObservationIgnored private var permissionRequester: IOSDeviceSettingsPermissions?
    @ObservationIgnored private var locationServicesEnabled: Bool?

    /// OpenClaw's own camera switch, on unless turned off.
    static var cameraEnabled: Bool {
        UserDefaults.standard.object(forKey: "camera.enabled") as? Bool ?? true
    }

    private static var locationMode: OpenClawLocationMode {
        UserDefaults.standard.string(forKey: "location.enabledMode")
            .flatMap(OpenClawLocationMode.init(rawValue:)) ?? .off
    }

    /// Turning the camera on also turns on OpenClaw's switch, which needs the
    /// same consent the device settings page asks for.
    func needsConsent(_ kind: SimplePhoneFeature.Kind) -> Bool {
        kind == .camera && !Self.cameraEnabled
    }

    func refresh(appModel: NodeAppModel) async {
        self.refreshPhone(appModel: appModel)
        self.locationServicesEnabled = await LocationService.servicesEnabled()
        self.refreshPhone(appModel: appModel)
        await self.refreshGateway(appModel: appModel)
    }

    func refreshPhone(appModel: NodeAppModel) {
        let entries = IOSDeviceSettingsPermissions.entries(
            notificationStatus: nil,
            locationAuthorization: appModel.locationAuthorizationSnapshot.authorizationStatus,
            locationServicesEnabled: self.locationServicesEnabled,
            photosAuthorization: PHPhotoLibrary.authorizationStatus(for: .readWrite))
        let statuses = Dictionary(entries.map { ($0.id, $0.status) }, uniquingKeysWith: { first, _ in first })
        self.phone = SimplePhoneFeature.features(
            statuses: statuses,
            cameraEnabled: Self.cameraEnabled,
            locationMode: Self.locationMode,
            locationAuthorization: appModel.locationAuthorizationSnapshot.authorizationStatus)
    }

    /// Asks iOS and turns on OpenClaw's own switch, as needed, for one
    /// feature. When what the phone advertises changes, refreshes the gateway
    /// registration the way the device settings page does. The caller asks
    /// for consent first when `needsConsent` says so.
    func turnOn(
        _ kind: SimplePhoneFeature.Kind,
        appModel: NodeAppModel,
        gatewayController: GatewayConnectionController) async
    {
        guard self.busyFeature == nil else { return }
        self.busyFeature = kind
        defer {
            self.busyFeature = nil
            self.refreshPhone(appModel: appModel)
        }
        let isCurrent: @MainActor @Sendable () -> Bool = { [weak self] in self != nil }
        var changed = false
        if kind == .location {
            let mode = Self.locationMode
            changed = await IOSDeviceSettingsActions.applyLocationMode(
                mode == .off ? .whileUsing : mode,
                appModel: appModel,
                isCurrent: isCurrent)
        } else {
            if self.phone.first(where: { $0.kind == kind })?.state == .askable {
                let requester = self.permissionRequester ?? IOSDeviceSettingsPermissions()
                self.permissionRequester = requester
                do {
                    try await requester.request(kind.permission, isCurrent: isCurrent)
                    changed = true
                } catch {
                    // Cancelled (the sheet went away); nothing changed.
                }
            }
            if self.needsConsent(kind) {
                UserDefaults.standard.set(true, forKey: "camera.enabled")
                changed = true
            }
        }
        if changed {
            gatewayController.refreshActiveGatewayRegistrationFromSettings()
        }
    }

    private func refreshGateway(appModel: NodeAppModel) async {
        if appModel.isScreenshotFixtureModeEnabled || appModel.isAppleReviewDemoModeEnabled {
            self.messaging = .loaded(SimpleConnectorsSample.messaging)
            self.skills = .loaded(SimpleConnectorsSample.skills)
            return
        }
        guard appModel.isOperatorGatewayConnected else {
            let message = String(localized: "Connect to your computer to see these.")
            self.messaging = .unavailable(message)
            self.skills = .unavailable(message)
            return
        }
        async let channels = Self.loadMessaging(appModel: appModel)
        async let skills = Self.loadSkills(appModel: appModel)
        self.messaging = await channels
        self.skills = await skills
    }

    private static func loadMessaging(appModel: NodeAppModel) async -> Load<[SimpleMessagingApp]> {
        do {
            let data = try await appModel.operatorSession.request(
                method: "channels.status",
                paramsJSON: "{}",
                timeoutSeconds: 12)
            let status = try JSONDecoder().decode(SimpleChannelsStatusLite.self, from: data)
            return .loaded(SimpleMessagingApp.apps(from: status))
        } catch {
            return .unavailable(String(localized: "Couldn't load messaging apps. Pull down to try again."))
        }
    }

    private static func loadSkills(appModel: NodeAppModel) async -> Load<[SimpleSkill]> {
        let request = OpenClawChatGatewayRequests.composerSkillsStatus(
            agentID: appModel.chatAgentId.trimmedNonEmpty)
        do {
            let data = try await appModel.operatorSession.request(
                method: request.method,
                params: request.params,
                timeoutMs: request.timeoutMs)
            let report = try JSONDecoder().decode(SkillsStatusReport.self, from: data)
            return .loaded(SimpleSkill.skills(from: report))
        } catch {
            return .unavailable(String(localized: "Couldn't load skills. Pull down to try again."))
        }
    }
}

/// Stand-in gateway data for screenshot and App Review demo modes, which have
/// no live gateway to ask.
enum SimpleConnectorsSample {
    static let messaging: [SimpleMessagingApp] = [
        SimpleMessagingApp(id: "telegram", name: "Telegram", systemImage: "paperplane", state: .connected),
        SimpleMessagingApp(
            id: "whatsapp",
            name: "WhatsApp",
            systemImage: "message",
            state: .attention("Linked device was signed out. Scan the code again on your computer.")),
        SimpleMessagingApp(id: "discord", name: "Discord", systemImage: nil, state: .notSetUp),
        SimpleMessagingApp(id: "slack", name: "Slack", systemImage: nil, state: .notSetUp),
        SimpleMessagingApp(id: "imessage", name: "iMessage", systemImage: "message.fill", state: .notSetUp),
    ]

    static let skills: [SimpleSkill] = [
        SimpleSkill(
            id: "apple-notes",
            name: "Apple Notes",
            emoji: "📝",
            summary: "Create, search, and edit notes.",
            state: .ready),
        SimpleSkill(
            id: "weather",
            name: "Weather",
            emoji: "🌤️",
            summary: "Current conditions and forecasts.",
            state: .ready),
        SimpleSkill(
            id: "summarize",
            name: "Summarize",
            emoji: "🧾",
            summary: "Summarize links, files, and videos.",
            state: .ready),
        SimpleSkill(
            id: "github",
            name: "GitHub",
            emoji: "🐙",
            summary: "Issues, pull requests, and CI runs.",
            state: .needsSetup("Needs gh installed on your computer")),
        SimpleSkill(
            id: "spotify-player",
            name: "Spotify Player",
            emoji: "🎵",
            summary: "Play and control music.",
            state: .needsSetup("Needs SPOTIFY_CLIENT_ID set on your computer")),
    ]
}
