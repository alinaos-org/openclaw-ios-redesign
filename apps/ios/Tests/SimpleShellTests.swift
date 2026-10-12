import Foundation
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
        ("read", "Working on files…"),
        ("apply_patch", "Working on files…"),
        ("exec", "Running a task…"),
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
