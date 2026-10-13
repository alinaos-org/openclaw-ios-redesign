import OpenClawKit
import OpenClawProtocol
import SwiftUI

// SIMPLE-UI: "Goals" — what your agent is working toward and keeping an eye on:
// the gateway's session goals ("Working on", with status and the latest note),
// goals it proposes, a field to start your own, its automations (cron jobs)
// as tracked check-ins, and templates that start a planning chat.

struct SimpleGoalTemplate: Identifiable, Hashable {
    let id: String
    let systemImage: String
    let title: String
    let prompt: String

    static var all: [SimpleGoalTemplate] {
        [
            make("health", "heart", String(localized: "Health"), String(localized: "my health and fitness")),
            make("money", "dollarsign.circle", String(localized: "Money"), String(localized: "saving or budgeting")),
            make("home", "house", String(localized: "Home"), String(localized: "keeping my home running")),
            make("learning", "book", String(localized: "Learning"), String(localized: "learning something new")),
            make(
                "relationships",
                "person.2",
                String(localized: "Relationships"),
                String(localized: "staying close to the people I care about")),
            make("work", "briefcase", String(localized: "Work"), String(localized: "my work and career")),
        ]
    }

    private static func make(_ id: String, _ systemImage: String, _ title: String, _ topic: String) -> Self {
        SimpleGoalTemplate(
            id: id,
            systemImage: systemImage,
            title: title,
            prompt: String(
                format: String(localized: """
                I want to set a goal around %@. Ask me what I want to achieve, help me turn it into a simple \
                plan, then set up a recurring check-in so you can keep me on track.
                """),
                topic))
    }
}

struct SimpleGoalsScreen: View {
    let jobs: [CronJob]
    let proposals: SimpleProposalsModel
    let agentName: String?
    let actions: SimpleProposalActions
    let onOpenJob: (CronJob) -> Void
    let onCreate: (SimpleGoalTemplate) -> Void

    @State private var showsAllTracking = false
    @State private var showsAllPaused = false

    private static let collapsedCount = 3

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                SimpleLargeTitle("Goals")
                self.workingOnSection
                SimpleProposalsSection(
                    kind: .goals,
                    model: self.proposals,
                    agentName: self.agentName,
                    actions: self.actions)
                    .padding(.bottom, 18)
                SimpleStartGoalCard(
                    agentName: self.agentName,
                    isStarting: self.proposals.busyIDs.contains("new-goal"),
                    onStart: self.actions.startGoal)
                    .padding(.bottom, 18)
                self.section(
                    title: "Tracking",
                    tint: SimplePalette.tracking,
                    halo: SimplePalette.trackingHalo,
                    jobs: self.trackingJobs,
                    expanded: self.$showsAllTracking)
                self.section(
                    title: "Paused",
                    tint: SimplePalette.paused,
                    halo: SimplePalette.pausedHalo,
                    jobs: self.pausedJobs,
                    expanded: self.$showsAllPaused)
                self.createSection
            }
            .padding(.bottom, SimpleMetric.scrollBottomPadding)
        }
        .scrollIndicators(.hidden)
        .simpleCanvas()
    }

    private var trackingJobs: [CronJob] {
        self.jobs
            .filter(\.enabled)
            .sorted { ($0.nextrunatms ?? .max) < ($1.nextrunatms ?? .max) }
    }

    private var pausedJobs: [CronJob] {
        self.jobs.filter { !$0.enabled }
    }

    @ViewBuilder
    private func section(
        title: LocalizedStringKey,
        tint: Color,
        halo: Color,
        jobs: [CronJob],
        expanded: Binding<Bool>) -> some View
    {
        if !jobs.isEmpty {
            SimpleDotSectionHeader(title: title, tint: tint, halo: halo)
            let visible = expanded.wrappedValue ? jobs : Array(jobs.prefix(Self.collapsedCount))
            ForEach(visible, id: \.id) { job in
                Button {
                    self.onOpenJob(job)
                } label: {
                    SimpleGoalRow(job: job)
                }
                .buttonStyle(SimpleRowButtonStyle())
                .accessibilityIdentifier("Simple.Goal.\(job.id)")
            }
            if jobs.count > Self.collapsedCount {
                Button {
                    withAnimation(.snappy) { expanded.wrappedValue.toggle() }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: expanded.wrappedValue ? "chevron.up" : "ellipsis")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(SimplePalette.tertiaryInk)
                            .frame(width: 24)
                        Text(expanded.wrappedValue
                            ? String(localized: "Show less")
                            : String(localized: "Show \(jobs.count - Self.collapsedCount) more"))
                            .font(OpenClawType.body)
                            .foregroundStyle(SimplePalette.tertiaryInk)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, SimpleMetric.gutter + 4)
                    .padding(.vertical, 12)
                }
                .buttonStyle(SimpleRowButtonStyle())
            }
            SimpleRowDivider(leadingInset: 0)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var workingOnSection: some View {
        if !self.proposals.goals.isEmpty {
            SimpleDotSectionHeader(
                title: "Working on",
                tint: SimplePalette.accent,
                halo: SimplePalette.accentTint)
            ForEach(self.proposals.goals) { goal in
                SimpleSessionGoalRow(
                    goal: goal,
                    isBusy: self.proposals.busyIDs.contains(goal.id),
                    onOpen: { self.actions.openGoal(goal) },
                    onAction: { self.actions.updateGoal(goal, $0) })
            }
            SimpleRowDivider(leadingInset: 0)
                .padding(.top, 8)
                .padding(.bottom, 18)
        }
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Plan something in chat")
                .font(OpenClawType.headline)
                .foregroundStyle(SimplePalette.ink)
                .padding(.horizontal, SimpleMetric.gutter + 4)
                .padding(.top, 22)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)
            ForEach(SimpleGoalTemplate.all) { template in
                Button {
                    self.onCreate(template)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: template.systemImage)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(SimplePalette.secondaryInk)
                            .frame(width: 28)
                        Text(verbatim: template.title)
                            .font(OpenClawType.body)
                            .foregroundStyle(SimplePalette.ink)
                        Spacer(minLength: 0)
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(SimplePalette.tertiaryInk)
                    }
                    .padding(.horizontal, SimpleMetric.gutter + 4)
                    .padding(.vertical, 13)
                }
                .buttonStyle(SimpleRowButtonStyle())
                .accessibilityHint(Text("Starts planning this goal in chat"))
                .accessibilityIdentifier("Simple.CreateGoal.\(template.id)")
            }
        }
    }
}

private struct SimpleGoalRow: View {
    let job: CronJob

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "square")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(SimplePalette.tertiaryInk)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: self.title)
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.ink)
                    .multilineTextAlignment(.leading)
                Text(verbatim: self.statusLine)
                    .font(OpenClawType.subhead)
                    .foregroundStyle(self.isFailing ? SimplePalette.attention : SimplePalette.secondaryInk)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SimplePalette.tertiaryInk)
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SimpleMetric.gutter + 4)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        self.job.displayname?.trimmedNonEmpty ?? self.job.name
    }

    private var isFailing: Bool {
        RootSidebarModel.isFailedCronJob(self.job)
    }

    private var statusLine: String {
        if self.isFailing {
            return String(localized: "Last check-in didn't finish. Tap to review.")
        }
        guard self.job.enabled else {
            return String(localized: "Paused")
        }
        if let nextRun = self.job.nextrunatms {
            let date = Date(timeIntervalSince1970: TimeInterval(nextRun) / 1000)
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return String(
                format: String(localized: "Next check-in %@"),
                formatter.localizedString(for: date, relativeTo: .now))
        }
        if let summary = self.job.description?.trimmedNonEmpty {
            return summary
        }
        return String(localized: "Tracking")
    }
}
