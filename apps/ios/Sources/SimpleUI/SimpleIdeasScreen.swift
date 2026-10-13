import SwiftUI

// SIMPLE-UI: "Ideas" — things your agent offers to take on. Its own proposals
// (`ideas.json` in its workspace; see SimpleProposals.swift) come first, then
// a curated catalog tuned to what an OpenClaw node can actually reach
// (calendar, reminders, Health, location, cron). Tapping either starts it in
// the main chat.

struct SimpleIdea: Identifiable, Hashable {
    let id: String
    let systemImage: String
    let tint: Color
    let title: String
    let detail: String
    let prompt: String
}

enum SimpleIdeaCatalog {
    static var starter: [SimpleIdea] {
        [
            SimpleIdea(
                id: "morning-brief",
                systemImage: "sun.horizon.fill",
                tint: SimplePalette.Tint.orange,
                title: String(localized: "I can brief you every morning"),
                detail: String(localized:
                    "Each weekday I'll pull your calendar, due reminders, and the weather into one short note."),
                prompt: String(localized: """
                Every weekday at 7:30 AM, send me a short morning briefing here with my calendar for the day, \
                any reminders that are due, and the weather where I am. Set it up as a recurring job and \
                confirm the schedule with me first.
                """)),
            SimpleIdea(
                id: "plan-week",
                systemImage: "calendar.badge.clock",
                tint: SimplePalette.Tint.blue,
                title: String(localized: "I can plan your week"),
                detail: String(localized:
                    "I'll look at the next seven days, flag conflicts, and suggest focus time around your meetings."),
                prompt: String(localized: """
                Look at my calendar for the next 7 days. Flag conflicts or overloaded days and suggest a few \
                focus blocks I could protect. Don't change my calendar until I say so.
                """)),
            SimpleIdea(
                id: "price-watch",
                systemImage: "tag.fill",
                tint: SimplePalette.Tint.green,
                title: String(localized: "I can watch a price for you"),
                detail: String(localized:
                    "Tell me what you're eyeing. I'll check daily and let you know when it drops below your target."),
                prompt: String(localized: """
                I want you to watch the price of something for me. Ask me what it is and my target price, \
                then check once a day and message me here when it drops below that.
                """)),
            SimpleIdea(
                id: "tidy-reminders",
                systemImage: "checklist",
                tint: SimplePalette.Tint.purple,
                title: String(localized: "I can tidy up your reminders"),
                detail: String(localized:
                    "I'll find overdue and duplicate reminders and suggest what to finish, reschedule, or drop."),
                prompt: String(localized: """
                Review my reminders. Find overdue and duplicate items and suggest what to finish, reschedule, \
                or delete. Don't change anything until I approve.
                """)),
            SimpleIdea(
                id: "health-weekly",
                systemImage: "heart.fill",
                tint: SimplePalette.Tint.pink,
                title: String(localized: "I can keep tabs on your health trends"),
                detail: String(localized:
                    "With Health access, I'll sum up your sleep, steps, and workouts each Sunday and flag changes."),
                prompt: String(localized: """
                Every Sunday evening, use my Health data to send me a short summary of my sleep, steps, and \
                workouts for the week, and point out anything that changed noticeably.
                """)),
            SimpleIdea(
                id: "get-to-know-me",
                systemImage: "person.crop.circle.badge.questionmark",
                tint: SimplePalette.Tint.teal,
                title: String(localized: "I can get to know you"),
                detail: String(localized:
                    "Tell me about your routines, people, and preferences. I'll remember them for next time."),
                prompt: String(localized: """
                I'd like you to get to know me. Ask me a few questions, one at a time, about my routines, the \
                important people in my life, and my preferences, and save what you learn to memory.
                """)),
            SimpleIdea(
                id: "draft-reply",
                systemImage: "envelope.fill",
                tint: SimplePalette.Tint.indigo,
                title: String(localized: "I can draft replies in your voice"),
                detail: String(localized:
                    "Paste a message and I'll write a reply for you to review. Nothing is sent without your OK."),
                prompt: String(localized: """
                Help me draft a reply. I'll paste the message. Ask me what I want to say, then write it in my \
                voice for me to review before anything is sent.
                """)),
            SimpleIdea(
                id: "arrival-reminder",
                systemImage: "location.fill",
                tint: SimplePalette.Tint.red,
                title: String(localized: "I can remind you when you arrive"),
                detail: String(localized: "Give me a place and a to-do. I'll nudge you when you get there."),
                prompt: String(localized: """
                Set up a location-based reminder. Ask me for the place and what I need to remember, and \
                nudge me when I arrive there.
                """)),
        ]
    }
}

struct SimpleIdeasScreen: View {
    let ideas: [SimpleIdea]
    let proposals: SimpleProposalsModel
    let agentName: String?
    let actions: SimpleProposalActions
    let onSelect: (SimpleIdea) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                SimpleLargeTitle("Ideas")
                SimpleProposalsSection(
                    kind: .ideas,
                    model: self.proposals,
                    agentName: self.agentName,
                    actions: self.actions)
                    .padding(.bottom, 18)
                Text("Ideas to try")
                    .font(OpenClawType.headline)
                    .foregroundStyle(SimplePalette.ink)
                    .padding(.horizontal, SimpleMetric.gutter + 4)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                ForEach(self.ideas) { idea in
                    Button {
                        self.onSelect(idea)
                    } label: {
                        SimpleIdeaRow(idea: idea)
                    }
                    .buttonStyle(SimpleRowButtonStyle())
                    .accessibilityHint(Text("Starts this in chat"))
                    .accessibilityIdentifier("Simple.Idea.\(idea.id)")
                    if idea.id != self.ideas.last?.id {
                        SimpleRowDivider(leadingInset: SimpleMetric.gutter + 4 + 44 + 14)
                    }
                }
            }
            .padding(.bottom, SimpleMetric.scrollBottomPadding)
        }
        .scrollIndicators(.hidden)
        .simpleCanvas()
    }
}

private struct SimpleIdeaRow: View {
    let idea: SimpleIdea

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SimpleIconTile(systemImage: self.idea.systemImage, tint: self.idea.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: self.idea.title)
                    .font(OpenClawType.headline)
                    .foregroundStyle(SimplePalette.ink)
                    .multilineTextAlignment(.leading)
                Text(verbatim: self.idea.detail)
                    .font(OpenClawType.subhead)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SimpleMetric.gutter + 4)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}
