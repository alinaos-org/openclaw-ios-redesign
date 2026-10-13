import CoreLocation
import Foundation
import OpenClawKit
import Testing
@testable import OpenClaw

// SIMPLE-UI: Logic coverage for the simple layout (Sources/SimpleUI).

struct SimpleAgentStatusTests {
    @Test(arguments: [
        ("browser", "Browsing the web…"),
        ("web_search", "Searching…"),
        ("web_fetch", "Reading a web page…"),
        ("calendar_events", "Checking your calendar…"),
        ("memory_search", "Searching…"),
        ("memory_get", "Updating memory…"),
        ("cron", "Scheduling…"),
        ("message", "Sending a message…"),
        ("sessions_spawn", "Asking a helper…"),
        ("read", "Reading files…"),
        ("apply_patch", "Editing files…"),
        ("write_file", "Editing files…"),
        ("exec", "Running a command…"),
        ("thread_summary", "Using thread summary…"),
        ("agents_list", "Using agents list…"),
    ])
    func `tool calls read as plain-language outcomes`(rawName: String, expected: String) {
        #expect(SimpleAgentStatus.toolPhrase(rawName: rawName, displayName: rawName) == expected)
    }

    @Test func `unknown tools fall back to a readable display name`() {
        #expect(SimpleAgentStatus
            .toolPhrase(rawName: "zz_custom_tool", displayName: "custom_tool") == "Using custom tool…")
    }

    @Test(arguments: [
        ("exec", "Ran a command"),
        ("web_fetch", "Read a web page"),
        ("cron", "Scheduled a check-in"),
        ("read", "Read files"),
    ])
    func `finished tool calls read in the past tense`(rawName: String, expected: String) {
        #expect(SimpleToolVocabulary.title(rawName: rawName, displayName: rawName, isRunning: false) == expected)
    }

    @Test func `unknown finished tools fall back to a readable display name`() {
        #expect(SimpleToolVocabulary.title(rawName: "zz_custom", displayName: "custom_tool", isRunning: false)
            == "Used custom tool")
    }

    @Test func `only active phases count as working`() {
        #expect(SimpleAgentStatus(phase: .thinking, text: nil).isWorking)
        #expect(SimpleAgentStatus(phase: .usingTool, text: nil).isWorking)
        #expect(SimpleAgentStatus(phase: .writing, text: nil).isWorking)
        #expect(!SimpleAgentStatus.idle.isWorking)
        #expect(!SimpleAgentStatus(phase: .offline, text: nil).isWorking)
        #expect(!SimpleAgentStatus(phase: .needsApproval, text: nil).isWorking)
    }

    @Test func `idle has no status line`() {
        #expect(SimpleAgentStatus.idle.text == nil)
    }
}

@MainActor
struct SimpleCatalogTests {
    @Test func `tabs are distinct`() {
        #expect(SimpleTab.allCases.count == 5)
        #expect(Set(SimpleTab.allCases.map(\.systemImage)).count == SimpleTab.allCases.count)
        #expect(Set(SimpleTab.allCases.map(\.title)).count == SimpleTab.allCases.count)
    }

    @Test func `ideas have unique ids and runnable prompts`() {
        let ideas = SimpleIdeaCatalog.starter
        #expect(!ideas.isEmpty)
        #expect(Set(ideas.map(\.id)).count == ideas.count)
        for idea in ideas {
            #expect(idea.title.hasPrefix("I can"), "Ideas speak in the agent's voice: \(idea.id)")
            #expect(!idea.detail.isEmpty)
            #expect(!idea.prompt.contains("\\"), "Line continuations must not leak into prompts: \(idea.id)")
            #expect(!idea.prompt.contains("  "), "Prompt has doubled spaces: \(idea.id)")
        }
    }

    @Test func `goal templates name their topic`() {
        let templates = SimpleGoalTemplate.all
        #expect(Set(templates.map(\.id)).count == templates.count)
        for template in templates {
            #expect(template.prompt.contains("goal around"))
            #expect(!template.prompt.contains("%@"))
        }
    }

    @Test func `more screen lists every non-tab destination once`() {
        let listed = SimpleMoreScreen.groups.flatMap(\.items).map(\.destination)
        #expect(Set(listed).count == listed.count)
        // Chat and Files are tabs; every other sidebar page stays reachable from More.
        let expected = Set(RootTabs.sidebarDestinations).subtracting([.chat, .files])
        #expect(expected.isSubset(of: Set(listed)))
        #expect(listed.contains(.settings))
        #expect(listed.contains(.gateway))
    }
}

struct SimpleShellPreferenceTests {
    @Test func `no shell is forced without launch flags`() {
        // The unit-test host launches without UI-test flags, so the stored
        // preference decides and no override is forced.
        #expect(SimpleShellPreference.launchOverride == nil)
    }
}

@MainActor
struct SimpleConnectorsTests {
    private static let allGranted: [DeviceSettingsPermission: DeviceSettingsPermissionStatus] = Dictionary(
        uniqueKeysWithValues: SimplePhoneFeature.Kind.allCases.map { ($0.permission, .granted) })

    private func state(
        _ kind: SimplePhoneFeature.Kind,
        statuses: [DeviceSettingsPermission: DeviceSettingsPermissionStatus] = SimpleConnectorsTests.allGranted,
        cameraEnabled: Bool = true,
        locationMode: OpenClawLocationMode = .whileUsing,
        locationAuthorization: CLAuthorizationStatus = .authorizedWhenInUse) -> SimplePhoneFeature.State?
    {
        SimplePhoneFeature.features(
            statuses: statuses,
            cameraEnabled: cameraEnabled,
            locationMode: locationMode,
            locationAuthorization: locationAuthorization)
            .first { $0.kind == kind }?.state
    }

    @Test func `iPhone features follow iOS permission status`() {
        var statuses = Self.allGranted
        statuses[.contacts] = .notDetermined
        statuses[.photos] = .denied
        statuses[.calendars] = .limited
        statuses[.camera] = .limited
        #expect(self.state(.contacts, statuses: statuses) == .askable)
        #expect(self.state(.photos, statuses: statuses) == .blocked(detail: "Off in iPhone Settings"))
        // "Add Events Only" can't read the calendar, so it isn't on for the agent.
        #expect(self.state(.calendar, statuses: statuses) == .blocked(detail: "Can add but not see"))
        #expect(self.state(.camera, statuses: statuses) == .on(detail: "Limited access"))
        #expect(self.state(.reminders, statuses: statuses) == .on(detail: nil))
    }

    @Test func `camera and location also need the OpenClaw switch`() {
        #expect(self.state(.camera, cameraEnabled: false) == .offInApp)
        #expect(self.state(.location, locationMode: .off) == .offInApp)
        #expect(self.state(.location, locationMode: .whileUsing) == .on(detail: "While using the app"))
        #expect(
            self.state(.location, locationMode: .always, locationAuthorization: .authorizedAlways)
                == .on(detail: "Always"))
        // Always mode with only While Using permission works in the foreground only.
        #expect(self.state(.location, locationMode: .always) == .on(detail: "While using the app"))
    }

    @Test func `messaging apps report status with set-up apps first`() throws {
        let json = """
        {
          "ts": 1,
          "channelOrder": ["discord", "telegram", "whatsapp", "slack", "signal", "matrix", "line"],
          "channelLabels": {"discord": "Discord", "telegram": "Telegram", "whatsapp": "WhatsApp",
                            "slack": "Slack", "signal": "Signal", "matrix": "Matrix", "line": "LINE"},
          "channelSystemImages": {"telegram": "paperplane"},
          "channels": {},
          "channelAccounts": {
            "telegram": [{"accountId": "default", "configured": true, "running": true}],
            "whatsapp": [{"accountId": "default", "configured": true, "connected": true}],
            "slack": [{"accountId": "default", "configured": true, "running": false}],
            "signal": [{"accountId": "default", "configured": true, "running": false, "lastError": "Daemon exited"}],
            "matrix": [{"accountId": "old", "enabled": false, "configured": true, "connected": true}],
            "line": [{"accountId": "default", "configured": true, "running": true, "connected": false}]
          },
          "channelDefaultAccountId": {},
          "statusIssues": [{"channel": "whatsapp", "accountId": "default", "kind": "auth",
                            "message": "Scan the QR code again."}]
        }
        """
        let status = try JSONDecoder().decode(SimpleChannelsStatusLite.self, from: Data(json.utf8))
        let apps = SimpleMessagingApp.apps(from: status)
        #expect(apps.map(\.id) == ["telegram", "whatsapp", "slack", "signal", "matrix", "line", "discord"])
        let states = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0.state) })
        #expect(states["telegram"] == .connected)
        #expect(states["whatsapp"] == .attention("Scan the QR code again."))
        #expect(states["slack"] == .off)
        #expect(states["signal"] == .attention("Daemon exited"))
        // A disabled account doesn't count as connected.
        #expect(states["matrix"] == .off)
        #expect(states["line"] == .attention("Reconnecting…"))
        #expect(states["discord"] == .notSetUp)
        #expect(apps.first?.systemImage == "paperplane")
    }

    @Test func `skills split into ready and needing setup`() throws {
        func skill(
            _ name: String,
            eligible: Bool,
            disabled: Bool = false,
            bins: [String] = [],
            env: [String] = []) -> String
        {
            let missing = "{\"bins\": \(bins), \"env\": \(env), \"config\": []}"
            return """
            {"name": "\(name)", "description": "About \(name)", "source": "bundled", "filePath": "/s",
             "baseDir": "/s", "skillKey": "\(name)", "always": false, "disabled": \(disabled),
             "eligible": \(eligible), "requirements": \(missing), "missing": \(missing),
             "configChecks": [], "install": []}
            """
        }
        let json = """
        {"workspaceDir": "/w", "managedSkillsDir": "/m", "skills": [
          \(skill("weather", eligible: true)),
          \(skill("github", eligible: false, bins: ["gh"])),
          \(skill("spotify-player", eligible: false, env: ["SPOTIFY_CLIENT_ID"])),
          \(skill("apple-notes", eligible: true)),
          \(skill("legacy", eligible: true, disabled: true))
        ]}
        """
        let report = try JSONDecoder().decode(SkillsStatusReport.self, from: Data(json.utf8))
        let skills = SimpleSkill.skills(from: report)
        #expect(skills.map(\.name) == ["Apple Notes", "Github", "Spotify Player", "Weather"])
        let states = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0.state) })
        #expect(states["weather"] == .ready)
        #expect(states["github"] == .needsSetup("Needs gh installed on your computer"))
        #expect(states["spotify-player"] == .needsSetup("Needs SPOTIFY_CLIENT_ID set on your computer"))
        #expect(states["legacy"] == nil)
    }
}

struct SimpleProposalsTests {
    @Test func `the ideas file yields ideas and goals`() throws {
        let json = """
        {"ideas": [
          {"id": "school", "kind": "idea", "title": "Summarize school emails", "summary": "Five arrived.",
           "prompt": "Summarize this week's school emails."},
          {"id": "10k", "kind": "Goal", "title": "Run a 10K", "prompt": "Get me ready for a 10K."},
          {"title": "Plan dinners"},
          {"id": "blank", "title": "   "},
          {"id": "untitled", "kind": "idea"}
        ]}
        """
        let proposals = try JSONDecoder().decode(SimpleIdeasFile.self, from: Data(json.utf8)).proposals
        #expect(proposals.map(\.id) == ["school", "10k", "plan dinners"])
        #expect(proposals.map(\.isGoal) == [false, true, false])
        #expect(proposals[1].summary.isEmpty)
        // A missing prompt falls back to the title so Start still has something to send.
        #expect(proposals[2].prompt == "Plan dinners")
    }

    @Test func `workspace files decode from text or base64`() throws {
        let content = #"{"ideas": []}"#
        let plain = """
        {"agentId": "main", "file": {"path": "ideas.json", "name": "ideas.json", "size": 13,
         "updatedAtMs": 1000, "mimeType": "application/json", "encoding": "utf8", "content": "{}"}}
        """
        #expect(try JSONDecoder().decode(SimpleWorkspaceFileLite.self, from: Data(plain.utf8)).text == "{}")
        let encoded = Data(content.utf8).base64EncodedString()
        let base64 = """
        {"agentId": "main", "file": {"path": "ideas.json", "name": "ideas.json", "size": 13,
         "updatedAtMs": 1000, "mimeType": "application/json", "encoding": "base64", "content": "\(encoded)"}}
        """
        #expect(try JSONDecoder().decode(SimpleWorkspaceFileLite.self, from: Data(base64.utf8)).text == content)
    }

    @Test func `goals come from session rows with unfinished ones first`() throws {
        let json = """
        {"sessions": [
          {"key": "agent:main:main"},
          {"key": "agent:main:ios-a", "goal": {"id": "a", "objective": "Plan Lisbon", "status": "complete",
           "updatedAt": 3000, "tokensUsed": 12, "lastStatusNote": "Booked."}},
          {"key": "agent:main:ios-b", "goal": {"id": "b", "objective": "Tidy inbox", "status": "paused",
           "updatedAt": 1000, "tokensUsed": 5}},
          {"key": "agent:main:ios-c", "goal": {"id": "c", "objective": "Run a 10K", "status": "active",
           "updatedAt": 2000, "tokensUsed": 7, "lastStatusNote": "  "}},
          {"key": "agent:main:ios-d", "goal": {"id": "d", "objective": "Learn Go", "status": "on_vacation",
           "updatedAt": 500, "tokensUsed": 1}}
        ]}
        """
        let list = try JSONDecoder().decode(SimpleSessionsGoalsLite.self, from: Data(json.utf8))
        let goals = SimpleSessionGoal.goals(from: list)
        #expect(goals.map(\.goalID) == ["c", "b", "d", "a"])
        #expect(goals.first?.sessionKey == "agent:main:ios-c")
        #expect(goals.first?.note == nil)
        let actions = Dictionary(uniqueKeysWithValues: goals.map { ($0.goalID, $0.actions) })
        #expect(actions["c"] == [.pause, .complete])
        #expect(actions["b"] == [.resume, .complete])
        #expect(actions["d"] == [])
        #expect(actions["a"] == [])
    }

    @Test func `asking for proposals names the file and its format`() {
        for kind in [SimpleProposalsModel.Kind.ideas, .goals] {
            let prompt = SimpleProposalPrompts.ask(kind)
            #expect(prompt.contains(SimpleIdeasFile.path))
            #expect(prompt.contains("\"kind\""))
        }
    }
}
