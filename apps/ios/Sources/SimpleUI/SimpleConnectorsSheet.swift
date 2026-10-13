import OpenClawChatUI
import OpenClawKit
import SwiftUI
import UIKit

// SIMPLE-UI: Connectors: everything the agent can reach, in one place. This
// iPhone's features come with a one-tap way to turn each on; messaging apps
// and skills are set up on the computer, so those sections report status and
// say what's missing. On phones that can open the gateway's dashboard (admin
// access, no browser sign-in), their rows open its Channels and Skills pages.

struct SimpleConnectorsSheet: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(GatewayConnectionController.self) private var gatewayController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var model = SimpleConnectorsModel()
    @State private var confirmsCamera = false
    @State private var showsAllReadySkills = false
    @State private var showsSkillsNeedingSetup = false

    /// Opens a dashboard page (path, title); RootTabs swaps it in for this sheet.
    var onOpenDashboard: ((String, String) -> Void)?

    private static let readySkillPreviewCount = 6

    /// Mirrors `DashboardPageScreen`, which otherwise falls back to native
    /// Settings, which has no channels or skills pages.
    private var canOpenDashboard: Bool {
        self.onOpenDashboard != nil
            && self.appModel.activeGatewayConnectConfig?.ingressAuthorization == nil
            && SettingsHubScreen.usesDashboard(
                isOperatorConnected: self.appModel.isOperatorGatewayConnected,
                hasOperatorAdminScope: self.appModel.hasOperatorAdminScope,
                isDemoMode: self.appModel.isAppleReviewDemoModeEnabled,
                isScreenshotMode: self.appModel.isScreenshotFixtureModeEnabled)
    }

    private var messagingLoaded: Bool {
        guard case .loaded = self.model.messaging else { return false }
        return true
    }

    private var skillsLoaded: Bool {
        guard case .loaded = self.model.skills else { return false }
        return true
    }

    private func dashboardLink(_ path: String, title: String) -> (() -> Void)? {
        guard self.canOpenDashboard, let onOpenDashboard = self.onOpenDashboard else { return nil }
        return { onOpenDashboard(path, title) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("""
                    Everything your agent can reach. Turn on iPhone features here; messaging apps \
                    and skills are set up on your computer.
                    """)
                    .font(OpenClawType.subhead)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SimpleMetric.gutter + 4)
                    .padding(.top, 4)

                    self.phoneSection
                    self.messagingSection
                    self.skillsSection
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .simpleCanvas()
            .refreshable {
                await self.model.refresh(appModel: self.appModel)
            }
            .navigationTitle(Text("Connectors"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.dismiss()
                    } label: {
                        Text("Done").font(OpenClawType.subheadSemiBold)
                    }
                    .accessibilityIdentifier("simple-connectors-done")
                }
            }
        }
        .tint(SimplePalette.accent)
        .task {
            await self.model.refresh(appModel: self.appModel)
        }
        .onChange(of: self.scenePhase) { _, phase in
            // Coming back from the Settings app.
            guard phase == .active else { return }
            self.model.refreshPhone(appModel: self.appModel)
        }
        .onChange(of: self.appModel.locationAuthorizationSnapshot) { _, _ in
            self.model.refreshPhone(appModel: self.appModel)
        }
        .alert(IOSDeviceSettingsConsent.camera.title, isPresented: self.$confirmsCamera) {
            Button(role: .cancel) {} label: {
                Text("Cancel").font(OpenClawType.subheadSemiBold)
            }
            Button {
                self.turnOn(.camera)
            } label: {
                Text("Allow").font(OpenClawType.subheadSemiBold)
            }
        } message: {
            Text(verbatim: IOSDeviceSettingsConsent.camera.detail)
                .font(OpenClawType.subhead)
        }
    }

    // MARK: Sections

    private var phoneSection: some View {
        SimpleConnectorsSection(
            title: Text("On this iPhone"),
            footer: nil,
            identifier: "simple-connectors-phone")
        {
            ForEach(self.model.phone) { feature in
                SimpleConnectorRow(
                    title: Text(verbatim: feature.kind.title),
                    subtitle: Text(verbatim: Self.subtitle(for: feature)))
                {
                    SimpleIconTile(systemImage: feature.kind.systemImage, tint: feature.kind.tint, size: 36)
                } trailing: {
                    self.phoneControl(for: feature)
                }
                .accessibilityIdentifier("simple-connector-phone-\(feature.kind.rawValue)")
                if feature.kind != self.model.phone.last?.kind {
                    SimpleRowDivider(leadingInset: Self.rowDividerInset)
                }
            }
        }
    }

    private var messagingSection: some View {
        let channelsLink = self.dashboardLink(
            DashboardRouteMap.channelsSettingsPath,
            title: String(localized: "Messaging apps"))
        return SimpleConnectorsSection(
            title: Text("Messaging apps"),
            footer: channelsLink != nil && self.messagingLoaded
                ? Text("Tap to add or manage messaging apps on your dashboard.")
                : Text("Add or change messaging apps from OpenClaw on your computer."),
            identifier: "simple-connectors-messaging")
        {
            switch self.model.messaging {
            case .loading:
                SimpleStatusNote(text: Text("Loading…"), showsProgress: true, insideCard: true)
            case let .unavailable(message):
                SimpleStatusNote(text: Text(verbatim: message), showsProgress: false, insideCard: true)
            case let .loaded(apps):
                let setUp = apps.filter(\.isSetUp)
                let available = apps.filter { !$0.isSetUp }
                if setUp.isEmpty {
                    SimpleConnectorLink(action: channelsLink) {
                        SimpleStatusNote(
                            text: Text("No messaging apps are set up yet."),
                            insideCard: true)
                    }
                }
                ForEach(setUp) { app in
                    SimpleConnectorLink(action: channelsLink) {
                        SimpleConnectorRow(
                            title: Text(verbatim: app.name),
                            subtitle: Self.subtitle(for: app))
                        {
                            SimpleIconTile(
                                systemImage: app.systemImage ?? "bubble.left.and.bubble.right",
                                tint: SimplePalette.Tint.green,
                                size: 36)
                        } trailing: {
                            Self.statusMark(for: app.state)
                        }
                    }
                    .accessibilityIdentifier("simple-connector-app-\(app.id)")
                    if app.id != setUp.last?.id || !available.isEmpty {
                        SimpleRowDivider(leadingInset: Self.rowDividerInset)
                    }
                }
                if !available.isEmpty {
                    // On dashboard phones this is the way to add one.
                    SimpleConnectorLink(action: channelsLink) {
                        Text(verbatim: Self.availableSummary(available))
                            .font(OpenClawType.footnote)
                            .foregroundStyle(SimplePalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var skillsSection: some View {
        SimpleConnectorsSection(
            title: Text("Skills"),
            footer: self.canOpenDashboard && self.skillsLoaded
                ? Text("Tap one to manage skills on your dashboard.")
                : Text("Skills are added and set up on your computer."),
            identifier: "simple-connectors-skills")
        {
            switch self.model.skills {
            case .loading:
                SimpleStatusNote(text: Text("Loading…"), showsProgress: true, insideCard: true)
            case let .unavailable(message):
                SimpleStatusNote(text: Text(verbatim: message), showsProgress: false, insideCard: true)
            case let .loaded(skills):
                let ready = skills.filter { $0.state == .ready }
                let needsSetup = skills.filter { $0.state != .ready }
                let shownReady = self.showsAllReadySkills ? ready : Array(ready.prefix(Self.readySkillPreviewCount))
                if ready.isEmpty {
                    SimpleStatusNote(text: Text("No skills are ready yet."), showsProgress: false, insideCard: true)
                }
                let hasMoreRows = ready.count > shownReady.count || !needsSetup.isEmpty
                ForEach(shownReady) { skill in
                    self.skillRow(skill)
                    if skill.id != shownReady.last?.id || hasMoreRows {
                        SimpleRowDivider(leadingInset: Self.rowDividerInset)
                    }
                }
                if ready.count > shownReady.count {
                    self.expandButton(
                        title: Text("Show all \(ready.count) ready skills"),
                        identifier: "simple-connectors-show-all-skills")
                    {
                        self.showsAllReadySkills = true
                    }
                    if !needsSetup.isEmpty {
                        SimpleRowDivider(leadingInset: 16)
                    }
                }
                if !needsSetup.isEmpty {
                    self.expandButton(
                        title: Text("\(needsSetup.count) more need setup"),
                        isExpanded: self.showsSkillsNeedingSetup,
                        identifier: "simple-connectors-skills-setup")
                    {
                        self.showsSkillsNeedingSetup.toggle()
                    }
                    if self.showsSkillsNeedingSetup {
                        ForEach(needsSetup) { skill in
                            SimpleRowDivider(leadingInset: Self.rowDividerInset)
                            self.skillRow(skill)
                        }
                    }
                }
            }
        }
    }

    // MARK: Rows

    private func skillRow(_ skill: SimpleSkill) -> some View {
        let subtitle = switch skill.state {
        case .ready:
            Text(verbatim: skill.summary)
        case let .needsSetup(missing):
            Text(verbatim: missing)
        }
        return SimpleConnectorLink(
            action: self.dashboardLink(DashboardRouteMap.skillsPagePath, title: String(localized: "Skills")))
        {
            SimpleConnectorRow(title: Text(verbatim: skill.name), subtitle: subtitle) {
                Text(verbatim: skill.emoji ?? "✨")
                    .font(OpenClawType.title3)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: SimpleMetric.iconTileRadius, style: .continuous)
                            .fill(SimplePalette.fill))
                    .accessibilityHidden(true)
            } trailing: {
                if skill.state == .ready {
                    Self.statusMark(for: .connected)
                }
            }
        }
        .accessibilityIdentifier("simple-connector-skill-\(skill.id)")
    }

    private func expandButton(
        title: Text,
        isExpanded: Bool = false,
        identifier: String,
        action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            HStack {
                title
                    .font(OpenClawType.subheadSemiBold)
                    .foregroundStyle(SimplePalette.accent)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SimplePalette.accent)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
        }
        .buttonStyle(SimpleRowButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func phoneControl(for feature: SimplePhoneFeature) -> some View {
        if self.model.busyFeature == feature.kind {
            ProgressView()
                .controlSize(.small)
        } else {
            switch feature.state {
            case .on:
                Self.statusMark(for: .connected)
            case .askable, .offInApp:
                SimpleCapsuleButton(title: Text("Turn on"), prominent: true) {
                    if self.model.needsConsent(feature.kind) {
                        self.confirmsCamera = true
                    } else {
                        self.turnOn(feature.kind)
                    }
                }
                .disabled(self.model.busyFeature != nil)
                .accessibilityIdentifier("simple-connector-turn-on-\(feature.kind.rawValue)")
            case .blocked:
                SimpleCapsuleButton(title: Text("Settings"), prominent: false) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        self.openURL(url)
                    }
                }
                .accessibilityHint(Text("Opens this app's page in the Settings app"))
            case .unavailable:
                Text("Unavailable")
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.tertiaryInk)
            }
        }
    }

    private func turnOn(_ kind: SimplePhoneFeature.Kind) {
        Task {
            await self.model.turnOn(kind, appModel: self.appModel, gatewayController: self.gatewayController)
        }
    }

    // MARK: Copy

    private static let rowDividerInset: CGFloat = 16 + 36 + 14

    private static func subtitle(for feature: SimplePhoneFeature) -> String {
        switch feature.state {
        case let .on(detail):
            detail.map { "\(feature.kind.subtitle) · \($0)" } ?? feature.kind.subtitle
        case .askable, .unavailable:
            feature.kind.subtitle
        case .offInApp:
            String(format: String(localized: "%@ · Off in OpenClaw"), feature.kind.subtitle)
        case let .blocked(detail):
            "\(feature.kind.subtitle) · \(detail)"
        }
    }

    private static func subtitle(for app: SimpleMessagingApp) -> Text {
        switch app.state {
        case .connected:
            Text("Connected")
        case let .attention(message):
            Text(verbatim: message)
        case .off:
            Text("Set up, but turned off")
        case .notSetUp:
            Text("Not set up")
        }
    }

    /// "Also available: Discord, Slack, and iMessage."
    private static func availableSummary(_ apps: [SimpleMessagingApp]) -> String {
        let shown = apps.prefix(8).map(\.name)
        var names = shown.formatted(.list(type: .and))
        if apps.count > shown.count {
            names = String(
                format: String(localized: "%@, and %lld more"),
                shown.joined(separator: ", "),
                Int64(apps.count - shown.count))
        }
        return String(format: String(localized: "Also available: %@."), names)
    }

    @ViewBuilder
    private static func statusMark(for state: SimpleMessagingApp.State) -> some View {
        switch state {
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SimplePalette.tracking)
                .accessibilityLabel(Text("On"))
        case .attention:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SimplePalette.attention)
                .accessibilityLabel(Text("Needs attention"))
        case .off, .notSetUp:
            EmptyView()
        }
    }
}

extension SimplePhoneFeature.Kind {
    var title: String {
        switch self {
        case .calendar: String(localized: "Calendar")
        case .reminders: String(localized: "Reminders")
        case .contacts: String(localized: "Contacts")
        case .photos: String(localized: "Photos")
        case .camera: String(localized: "Camera")
        case .microphone: String(localized: "Microphone")
        case .location: String(localized: "Location")
        }
    }

    var subtitle: String {
        switch self {
        case .calendar: String(localized: "See and add events")
        case .reminders: String(localized: "See and add reminders")
        case .contacts: String(localized: "Look up people you know")
        case .photos: String(localized: "Find and share your photos")
        case .camera: String(localized: "Take photos and video")
        case .microphone: String(localized: "Talk to your agent out loud")
        case .location: String(localized: "Share where this iPhone is")
        }
    }

    var systemImage: String {
        switch self {
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .contacts: "person.crop.circle"
        case .photos: "photo.on.rectangle"
        case .camera: "camera"
        case .microphone: "mic"
        case .location: "location"
        }
    }

    var tint: Color {
        switch self {
        case .calendar: SimplePalette.Tint.red
        case .reminders: SimplePalette.Tint.orange
        case .contacts: SimplePalette.Tint.brown
        case .photos: SimplePalette.Tint.pink
        case .camera: SimplePalette.Tint.gray
        case .microphone: SimplePalette.Tint.purple
        case .location: SimplePalette.Tint.blue
        }
    }
}

// MARK: - Building blocks

private struct SimpleConnectorsSection<Content: View>: View {
    let title: Text
    let footer: Text?
    let identifier: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SimpleSectionTitle(text: self.title)
            SimpleCard {
                self.content
            }
            if let footer {
                footer
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SimpleMetric.gutter + 4)
            }
        }
        .padding(.top, 24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(self.identifier)
    }
}

/// A row that opens a dashboard page when the phone can show one, and is
/// plain status otherwise.
private struct SimpleConnectorLink<Content: View>: View {
    let action: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        if let action {
            Button(action: action) {
                HStack(spacing: 0) {
                    self.content
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SimplePalette.tertiaryInk)
                        .padding(.trailing, 16)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(SimpleRowButtonStyle())
            .accessibilityHint(Text("Opens it on your dashboard"))
        } else {
            self.content
        }
    }
}

private struct SimpleConnectorRow<Icon: View, Trailing: View>: View {
    let title: Text
    let subtitle: Text
    @ViewBuilder let icon: Icon
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            self.icon
            VStack(alignment: .leading, spacing: 2) {
                self.title
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.ink)
                self.subtitle
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            self.trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .accessibilityElement(children: .contain)
    }
}
