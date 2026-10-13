import OpenClawChatUI
import OpenClawKit
import SwiftUI
import UIKit

// SIMPLE-UI: Connectors: everything the agent can reach, in one place. This
// iPhone's features come with a one-tap way to turn each on; messaging apps
// and skills are set up on the computer, so those sections report status and
// say what's missing.

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

    private static let readySkillPreviewCount = 6

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
        SimpleConnectorsSection(
            title: Text("Messaging apps"),
            footer: Text("Add or change messaging apps from OpenClaw on your computer."),
            identifier: "simple-connectors-messaging")
        {
            switch self.model.messaging {
            case .loading:
                SimpleConnectorsPlaceholder(text: Text("Loading…"), showsProgress: true)
            case let .unavailable(message):
                SimpleConnectorsPlaceholder(text: Text(verbatim: message), showsProgress: false)
            case let .loaded(apps):
                let setUp = apps.filter(\.isSetUp)
                let available = apps.filter { !$0.isSetUp }
                if setUp.isEmpty {
                    SimpleConnectorsPlaceholder(
                        text: Text("No messaging apps are set up yet."),
                        showsProgress: false)
                }
                ForEach(setUp) { app in
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
                    .accessibilityIdentifier("simple-connector-app-\(app.id)")
                    if app.id != setUp.last?.id || !available.isEmpty {
                        SimpleRowDivider(leadingInset: Self.rowDividerInset)
                    }
                }
                if !available.isEmpty {
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

    private var skillsSection: some View {
        SimpleConnectorsSection(
            title: Text("Skills"),
            footer: Text("Skills are added and set up on your computer."),
            identifier: "simple-connectors-skills")
        {
            switch self.model.skills {
            case .loading:
                SimpleConnectorsPlaceholder(text: Text("Loading…"), showsProgress: true)
            case let .unavailable(message):
                SimpleConnectorsPlaceholder(text: Text(verbatim: message), showsProgress: false)
            case let .loaded(skills):
                let ready = skills.filter { $0.state == .ready }
                let needsSetup = skills.filter { $0.state != .ready }
                let shownReady = self.showsAllReadySkills ? ready : Array(ready.prefix(Self.readySkillPreviewCount))
                if ready.isEmpty {
                    SimpleConnectorsPlaceholder(text: Text("No skills are ready yet."), showsProgress: false)
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
        return SimpleConnectorRow(title: Text(verbatim: skill.name), subtitle: subtitle) {
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
                SimpleConnectorButton(title: Text("Turn on"), prominent: true) {
                    if self.model.needsConsent(feature.kind) {
                        self.confirmsCamera = true
                    } else {
                        self.turnOn(feature.kind)
                    }
                }
                .disabled(self.model.busyFeature != nil)
                .accessibilityIdentifier("simple-connector-turn-on-\(feature.kind.rawValue)")
            case .blocked:
                SimpleConnectorButton(title: Text("Settings"), prominent: false) {
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
            self.title
                .font(OpenClawType.footnoteSemiBold)
                .foregroundStyle(SimplePalette.secondaryInk)
                .textCase(.uppercase)
                .padding(.horizontal, SimpleMetric.gutter + 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                self.content
            }
            .background(SimplePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                    .stroke(SimplePalette.hairline, lineWidth: 0.5)
            }
            .padding(.horizontal, SimpleMetric.gutter)
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

private struct SimpleConnectorButton: View {
    let title: Text
    let prominent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            self.title
                .font(OpenClawType.footnoteSemiBold)
                .foregroundStyle(self.prominent ? Color.white : SimplePalette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .background(Capsule().fill(self.prominent ? SimplePalette.accent : SimplePalette.fill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SimpleConnectorsPlaceholder: View {
    let text: Text
    let showsProgress: Bool

    var body: some View {
        HStack(spacing: 10) {
            if self.showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
            self.text
                .font(OpenClawType.subhead)
                .foregroundStyle(SimplePalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
