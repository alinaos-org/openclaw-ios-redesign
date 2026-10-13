import OpenClawChatUI
import OpenClawKit
import OpenClawProtocol
import SwiftUI

// SIMPLE-UI: Tapping the agent opens its profile: who it is, what it's doing
// right now (with a stop button), and four tabs: Activity (what it did),
// Permissions (what it may do without asking), Upcoming (scheduled
// check-ins), and Memory (what it remembers about you). Data lives in
// `SimpleProfileModel`; each tab links to the full screen for more.

struct SimpleAgentProfileSheet: View {
    enum Tab: String, CaseIterable, Identifiable {
        case activity
        case permissions
        case upcoming
        case memory

        var id: String {
            self.rawValue
        }

        var title: String {
            switch self {
            case .activity: String(localized: "Activity")
            case .permissions: String(localized: "Permissions")
            case .upcoming: String(localized: "Upcoming")
            case .memory: String(localized: "Memory")
            }
        }
    }

    /// Where the tabs' "see more" links lead.
    enum Link {
        case allActivity
        case connectors
        case goals
        case library
    }

    let jobs: [CronJob]
    let onStop: () -> Void
    let onOpen: (Link) -> Void

    @Environment(NodeAppModel.self) private var appModel
    @State private var tab: Tab = .activity
    @State private var model = SimpleProfileModel()

    var body: some View {
        let name = SimpleAgentIdentity.displayName(appModel: self.appModel)
        let status = SimpleAgentStatus.resolve(appModel: self.appModel)
        ScrollView {
            VStack(spacing: 0) {
                OpenClawMascotView(floats: true, mood: status.mood, interactive: true)
                    .frame(width: 96, height: 96)
                    .padding(.top, 24)
                    .accessibilityHidden(true)
                Text(verbatim: name)
                    .font(OpenClawType.title2SemiBold)
                    .foregroundStyle(SimplePalette.ink)
                    .padding(.top, 8)
                Text(verbatim: status.text ?? String(localized: "Ready when you are"))
                    .font(OpenClawType.callout)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .padding(.top, 2)
                if status.isWorking {
                    Button(action: self.onStop) {
                        Label {
                            Text("Stop current task")
                                .font(OpenClawType.subheadSemiBold)
                        } icon: {
                            Image(systemName: "stop.fill")
                        }
                        .foregroundStyle(SimplePalette.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(SimplePalette.fill))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .accessibilityIdentifier("Simple.Profile.Stop")
                }
                SimpleProfileTabPicker(selection: self.$tab)
                    .padding(.horizontal, SimpleMetric.gutter)
                    .padding(.top, 22)
                self.content
                    .padding(.top, 16)
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .simpleCanvas()
        .refreshable {
            await self.model.refresh(appModel: self.appModel)
        }
        .task {
            await self.model.refresh(appModel: self.appModel)
        }
        .alert(Text("Something went wrong"), isPresented: self.showsError) {
            Button(role: .cancel) {} label: {
                Text("OK").font(OpenClawType.subheadSemiBold)
            }
        } message: {
            Text(verbatim: self.model.errorMessage ?? "")
                .font(OpenClawType.subhead)
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(SimpleMetric.cardRadius)
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: { self.model.errorMessage != nil },
            set: { if !$0 { self.model.clearError() } })
    }

    @ViewBuilder
    private var content: some View {
        switch self.tab {
        case .activity:
            SimpleProfileActivityTab(load: self.model.activity) { self.onOpen(.allActivity) }
        case .permissions:
            SimpleProfilePermissionsTab(
                load: self.model.grants,
                revokingIDs: self.model.revokingIDs,
                onRevoke: { grant in Task { await self.model.revoke(grant, appModel: self.appModel) } },
                onOpenConnectors: { self.onOpen(.connectors) })
        case .upcoming:
            SimpleProfileUpcomingTab(jobs: SimpleAgentIdentity.jobs(self.jobs, appModel: self.appModel)) {
                self.onOpen(.goals)
            }
        case .memory:
            SimpleProfileMemoryTab(load: self.model.memory) { self.onOpen(.library) }
        }
    }
}

// MARK: - Tab picker

private struct SimpleProfileTabPicker: View {
    @Binding var selection: SimpleAgentProfileSheet.Tab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SimpleAgentProfileSheet.Tab.allCases) { tab in
                let isSelected = self.selection == tab
                Button {
                    withAnimation(.snappy(duration: 0.2)) { self.selection = tab }
                } label: {
                    Text(verbatim: tab.title)
                        .font(OpenClawType.footnoteSemiBold)
                        .foregroundStyle(isSelected ? SimplePalette.ink : SimplePalette.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(SimplePalette.surface)
                                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("Simple.Profile.Tab.\(tab.rawValue)")
            }
        }
        .padding(3)
        .background(Capsule().fill(SimplePalette.fill))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Tabs

private struct SimpleProfileActivityTab: View {
    let load: SimpleProfileModel.Load<[SimpleActivityItem]>
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch self.load {
            case .loading:
                SimpleStatusNote(text: Text("Loading…"), showsProgress: true)
            case let .unavailable(message):
                SimpleStatusNote(text: Text(verbatim: message), showsProgress: false)
            case let .loaded(items) where items.isEmpty:
                SimpleStatusNote(
                    text: Text("Nothing yet. When I search, read, or run things for you, it shows up here."),
                    showsProgress: false)
            case let .loaded(items):
                ForEach(Self.days(items), id: \.day) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        SimpleSectionTitle(text: Text(verbatim: Self.dayTitle(group.day)))
                        SimpleCard {
                            ForEach(group.items) { item in
                                SimpleProfileActivityRow(item: item)
                                if item.id != group.items.last?.id {
                                    SimpleRowDivider(leadingInset: 16 + 24 + 12)
                                }
                            }
                        }
                    }
                }
            }
            SimpleProfileLinkButton(title: Text("See all activity"), action: self.onSeeAll)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Simple.Profile.ActivityTab")
    }

    private struct DayGroup {
        let day: Date
        let items: [SimpleActivityItem]
    }

    private static func days(_ items: [SimpleActivityItem]) -> [DayGroup] {
        var groups: [DayGroup] = []
        for item in items {
            let day = Calendar.current.startOfDay(for: item.occurredAt)
            if let last = groups.last, last.day == day {
                groups[groups.count - 1] = DayGroup(day: day, items: last.items + [item])
            } else {
                groups.append(DayGroup(day: day, items: [item]))
            }
        }
        return groups
    }

    private static func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return String(localized: "Today") }
        if Calendar.current.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct SimpleProfileActivityRow: View {
    let item: SimpleActivityItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: self.item.failed ? "exclamationmark.triangle.fill" : "checkmark.circle")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(self.item.failed ? SimplePalette.attention : SimplePalette.tertiaryInk)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: self.title)
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.ink)
                if self.item.failed {
                    Text("Didn't finish")
                        .font(OpenClawType.footnote)
                        .foregroundStyle(SimplePalette.attention)
                }
            }
            Spacer(minLength: 8)
            Text(verbatim: self.item.occurredAt.formatted(date: .omitted, time: .shortened))
                .font(OpenClawType.footnote)
                .foregroundStyle(SimplePalette.tertiaryInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        guard self.item.count > 1 else { return self.item.title }
        return String(format: String(localized: "%@ · %lld times"), self.item.title, Int64(self.item.count))
    }
}

private struct SimpleProfilePermissionsTab: View {
    let load: SimpleProfileModel.Load<[SimpleStandingGrant]>
    let revokingIDs: Set<String>
    let onRevoke: (SimpleStandingGrant) -> Void
    let onOpenConnectors: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SimpleSectionTitle(text: Text("Without asking"))
                switch self.load {
                case .loading:
                    SimpleStatusNote(text: Text("Loading…"), showsProgress: true)
                case let .unavailable(message):
                    SimpleStatusNote(text: Text(verbatim: message), showsProgress: false)
                case let .loaded(grants) where grants.isEmpty:
                    SimpleStatusNote(
                        text: Text("""
                        Nothing yet. When you tap Always allow on a request from one of my automations, it \
                        shows up here.
                        """),
                        showsProgress: false)
                case let .loaded(grants):
                    SimpleCard {
                        ForEach(grants) { grant in
                            self.row(grant)
                            if grant.id != grants.last?.id {
                                SimpleRowDivider(leadingInset: 16)
                            }
                        }
                    }
                }
            }
            Text("Anything else follows the approval rules on your computer.")
                .font(OpenClawType.footnote)
                .foregroundStyle(SimplePalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SimpleMetric.gutter + 4)
            SimpleCard {
                Button(action: self.onOpenConnectors) {
                    HStack(spacing: 14) {
                        SimpleIconTile(systemImage: "iphone", tint: SimplePalette.accent, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iPhone features")
                                .font(OpenClawType.body)
                                .foregroundStyle(SimplePalette.ink)
                            Text("Calendar, location, camera, and more")
                                .font(OpenClawType.footnote)
                                .foregroundStyle(SimplePalette.secondaryInk)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SimplePalette.tertiaryInk)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(SimpleRowButtonStyle())
                .accessibilityIdentifier("Simple.Profile.Connectors")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Simple.Profile.PermissionsTab")
    }

    private func row(_ grant: SimpleStandingGrant) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: grant.automation ?? String(localized: "An automation"))
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.ink)
                Text(verbatim: grant.command)
                    .font(OpenClawType.monoSmall)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(verbatim: Self.usage(grant))
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.tertiaryInk)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if self.revokingIDs.contains(grant.id) {
                ProgressView()
                    .controlSize(.small)
                    .frame(minHeight: 32)
            } else {
                SimpleCapsuleButton(title: Text("Remove"), prominent: false) {
                    self.onRevoke(grant)
                }
                .accessibilityHint(Text("Asks again next time"))
                .accessibilityIdentifier("Simple.Profile.Revoke.\(grant.id)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private static func usage(_ grant: SimpleStandingGrant) -> String {
        let uses = grant.useCount == 1
            ? String(localized: "Used once")
            : String(format: String(localized: "Used %lld times"), Int64(grant.useCount))
        guard let lastUsed = grant.lastUsedAt else { return uses }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "\(uses) · \(formatter.localizedString(for: lastUsed, relativeTo: .now))"
    }
}

private struct SimpleProfileUpcomingTab: View {
    let jobs: [CronJob]
    let onOpenGoals: () -> Void

    var body: some View {
        let upcoming = self.jobs
            .filter(\.enabled)
            .sorted { ($0.nextrunatms ?? .max) < ($1.nextrunatms ?? .max) }
        VStack(alignment: .leading, spacing: 14) {
            if upcoming.isEmpty {
                SimpleStatusNote(
                    text: Text("Nothing scheduled. Ask me to check in on something and it shows up here."),
                    showsProgress: false)
            } else {
                SimpleCard {
                    ForEach(upcoming, id: \.id) { job in
                        SimpleProfileUpcomingRow(job: job)
                        if job.id != upcoming.last?.id {
                            SimpleRowDivider(leadingInset: 16 + 24 + 12)
                        }
                    }
                }
            }
            SimpleProfileLinkButton(title: Text("Open Goals"), action: self.onOpenGoals)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Simple.Profile.UpcomingTab")
    }
}

private struct SimpleProfileUpcomingRow: View {
    let job: CronJob

    var body: some View {
        let failing = RootSidebarModel.isFailedCronJob(self.job)
        HStack(spacing: 12) {
            Image(systemName: failing ? "exclamationmark.triangle.fill" : "clock")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(failing ? SimplePalette.attention : SimplePalette.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: self.job.displayname?.trimmedNonEmpty ?? self.job.name)
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.ink)
                Text(verbatim: failing ? String(localized: "Last check-in didn't finish") : self.nextRun)
                    .font(OpenClawType.footnote)
                    .foregroundStyle(failing ? SimplePalette.attention : SimplePalette.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Simple.Profile.Upcoming.\(self.job.id)")
    }

    private var nextRun: String {
        guard let next = self.job.nextrunatms else { return String(localized: "Not scheduled yet") }
        let date = Date(timeIntervalSince1970: TimeInterval(next) / 1000)
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return String(format: String(localized: "Today at %@"), time)
        }
        if Calendar.current.isDateInTomorrow(date) {
            return String(format: String(localized: "Tomorrow at %@"), time)
        }
        return String(
            format: String(localized: "%@ at %@"),
            date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
            time)
    }
}

private struct SimpleProfileMemoryTab: View {
    let load: SimpleProfileModel.Load<[SimpleMemoryBlock]>
    let onSeeFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch self.load {
            case .loading:
                SimpleStatusNote(text: Text("Loading…"), showsProgress: true)
            case let .unavailable(message):
                SimpleStatusNote(text: Text(verbatim: message), showsProgress: false)
            case let .loaded(blocks) where blocks.isEmpty:
                SimpleStatusNote(
                    text: Text("""
                    I haven't saved anything about you yet. Tell me what matters to you and I'll remember it.
                    """),
                    showsProgress: false)
            case let .loaded(blocks):
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        Self.view(for: block)
                    }
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
            }
            SimpleProfileLinkButton(title: Text("See all memory files"), action: self.onSeeFiles)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Simple.Profile.MemoryTab")
    }

    @ViewBuilder
    private static func view(for block: SimpleMemoryBlock) -> some View {
        switch block {
        case let .heading(text):
            Text(Self.inline(text, base: OpenClawType.headline, strong: OpenClawType.headline))
                .font(OpenClawType.headline)
                .foregroundStyle(SimplePalette.ink)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
        case let .bullet(text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "•")
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.tertiaryInk)
                    .accessibilityHidden(true)
                Text(Self.inline(text, base: OpenClawType.body, strong: OpenClawType.headline))
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case let .paragraph(text):
            Text(Self.inline(text, base: OpenClawType.body, strong: OpenClawType.headline))
                .font(OpenClawType.body)
                .foregroundStyle(SimplePalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Bold, italics, code, and links inside a line, in the app's fonts.
    /// Each run gets an explicit font: left to SwiftUI, emphasized runs fall
    /// back to the system font at a different size.
    private static func inline(_ text: String, base: Font, strong: Font) -> AttributedString {
        guard var attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        else { return AttributedString(text) }
        for run in attributed.runs {
            let intent = run.inlinePresentationIntent ?? []
            var font = intent.contains(.stronglyEmphasized) ? strong : base
            if intent.contains(.code) { font = OpenClawType.monoSmall }
            if intent.contains(.emphasized) { font = font.italic() }
            attributed[run.range].font = font
            attributed[run.range].inlinePresentationIntent = nil
        }
        return attributed
    }
}

// MARK: - Building blocks

private struct SimpleProfileLinkButton: View {
    let title: Text
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 4) {
                self.title
                    .font(OpenClawType.subheadSemiBold)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(SimplePalette.accent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SimpleMetric.gutter + 4)
    }
}
