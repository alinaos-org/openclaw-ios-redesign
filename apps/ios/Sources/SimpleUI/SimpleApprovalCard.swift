import OpenClawKit
import OpenClawProtocol
import SwiftUI

// SIMPLE-UI: The approval card in the simple layout. Same decisions and states
// as upstream's `ExecApprovalPromptCard`, presented as a plain-language
// request: who wants to do what, what to check, then Deny / Allow.

extension EnvironmentValues {
    /// Set by the simple layout so approval dialogs use `SimpleApprovalCard`.
    @Entry var usesSimpleApprovalCard = false
}

struct SimpleApprovalCard: View {
    let prompt: NodeAppModel.ExecApprovalPrompt
    let agentName: String
    let isResolving: Bool
    let canDismiss: Bool
    let errorText: String?
    let resolvedText: String?
    let resolvedTone: NodeAppModel.ExecApprovalOutcomeTone?
    let onDecision: (ApprovalDecision) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    self.header
                    self.preview
                    if let warningText = self.prompt.warningText?.trimmedNonEmpty {
                        Label {
                            Text(verbatim: warningText)
                                .font(OpenClawType.footnote)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(SimplePalette.attention)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    self.details
                    self.status
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("simple-approval-review")

            self.actions
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 4)
                .accessibilityIdentifier("simple-approval-actions")
        }
        .background(
            RoundedRectangle(cornerRadius: SimpleMetric.cardRadius, style: .continuous)
                .fill(SimplePalette.surface))
        .overlay(
            RoundedRectangle(cornerRadius: SimpleMetric.cardRadius, style: .continuous)
                .stroke(SimplePalette.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 30, y: 12)
        .accessibilityIdentifier("simple-approval-card")
    }

    // MARK: Content

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            SimpleIconTile(systemImage: self.symbol, tint: SimplePalette.accent, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: self.title)
                    .font(OpenClawType.headline)
                    .foregroundStyle(SimplePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: self.subtitle)
                    .font(OpenClawType.subhead)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// What will actually happen: the command for exec requests, otherwise the
    /// request's own summary when it adds something beyond the title.
    @ViewBuilder
    private var preview: some View {
        if self.isExec {
            Text(verbatim: self.prompt.commandText)
                .font(OpenClawType.mono)
                .foregroundStyle(SimplePalette.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                        .fill(SimplePalette.fill))
                .accessibilityLabel(Text("Command: \(self.prompt.commandText)"))
        } else if let description = self.prompt.descriptionText?.trimmedNonEmpty,
                  description != self.prompt.commandText
        {
            Text(verbatim: description)
                .font(OpenClawType.callout)
                .foregroundStyle(SimplePalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var details: some View {
        let rows = self.detailRows
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.label)
                            .font(OpenClawType.subhead)
                            .foregroundStyle(SimplePalette.secondaryInk)
                        Spacer(minLength: 8)
                        Text(verbatim: row.value)
                            .font(OpenClawType.subheadMedium)
                            .foregroundStyle(SimplePalette.ink)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                    if index < rows.count - 1 {
                        SimpleRowDivider(leadingInset: 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                    .fill(SimplePalette.fill))
        }
    }

    @ViewBuilder
    private var status: some View {
        if let errorText = self.errorText?.trimmedNonEmpty {
            Text(verbatim: errorText)
                .font(OpenClawType.footnote)
                .foregroundStyle(OpenClawBrand.danger)
        }
        if let resolvedText = self.resolvedText?.trimmedNonEmpty {
            Label {
                Text(verbatim: resolvedText)
                    .font(OpenClawType.subheadMedium)
            } icon: {
                Image(systemName: self.resolvedSymbol)
            }
            .foregroundStyle(self.resolvedColor)
        }
        if self.isResolving {
            HStack(spacing: 8) {
                ProgressView()
                Text("Sending your answer…")
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.secondaryInk)
            }
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        if self.resolvedText != nil {
            self.capsuleButton(Text("Done"), prominent: true, identifier: "simple-approval-done", action: self.onCancel)
        } else {
            VStack(spacing: 12) {
                if self.prompt.kind == "system-agent" {
                    ApprovalDashboardReviewButton(prompt: self.prompt)
                }
                HStack(spacing: 12) {
                    if self.prompt.allowsDeny {
                        self.capsuleButton(Text("Deny"), prominent: false, identifier: "simple-approval-deny") {
                            self.onDecision(.deny)
                        }
                        .disabled(self.isResolving)
                    }
                    if let allow = self.primaryAllowDecision {
                        self.capsuleButton(Text("Allow"), prominent: true, identifier: "simple-approval-allow") {
                            self.onDecision(allow)
                        }
                        .disabled(self.isResolving)
                    }
                }
                if self.prompt.allowsAllowOnce, self.prompt.allowsAllowAlways {
                    Button {
                        self.onDecision(.allowAlways)
                    } label: {
                        Text("Always allow this")
                            .font(OpenClawType.subheadMedium)
                            .foregroundStyle(SimplePalette.accent)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(self.isResolving)
                    .accessibilityIdentifier("simple-approval-allow-always")
                }
                if self.canDismiss {
                    Button(action: self.onCancel) {
                        Text("Decide later")
                            .font(OpenClawType.subhead)
                            .foregroundStyle(SimplePalette.secondaryInk)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Keeps the request waiting without answering it"))
                    .accessibilityIdentifier("simple-approval-later")
                }
            }
        }
    }

    private func capsuleButton(
        _ title: Text,
        prominent: Bool,
        identifier: String,
        action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            title
                .font(OpenClawType.subheadSemiBold)
                .foregroundStyle(prominent ? Color.white : SimplePalette.ink)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(prominent ? SimplePalette.accent : SimplePalette.fill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: Presentation

    private var isExec: Bool {
        self.prompt.kind == nil || self.prompt.kind == "exec"
    }

    /// "Allow" means the narrowest grant the request offers.
    private var primaryAllowDecision: ApprovalDecision? {
        if self.prompt.allowsAllowOnce { return .allowOnce }
        if self.prompt.allowsAllowAlways { return .allowAlways }
        return nil
    }

    private var symbol: String {
        switch self.prompt.kind {
        case "plugin": "puzzlepiece.extension"
        case "system-agent": "person.badge.shield.checkmark"
        case nil, "exec": "terminal"
        default: "hand.raised"
        }
    }

    private var title: String {
        if self.isExec {
            return String(format: String(localized: "%@ wants to run a command"), self.agentName)
        }
        if self.prompt.kind == "plugin", let tool = self.prompt.toolName?.trimmedNonEmpty {
            return String(format: String(localized: "%@ wants to use %@"), self.agentName, tool)
        }
        return self.prompt.commandText
    }

    private var subtitle: String {
        if self.isExec {
            return String(localized: "Check what it does before allowing it. It runs with your permissions.")
        }
        return String(localized: "Make sure you expect this before allowing it.")
    }

    private struct DetailRow {
        let label: LocalizedStringKey
        let value: String
    }

    private var detailRows: [DetailRow] {
        var rows: [DetailRow] = []
        if self.prompt.kind == "plugin" {
            if let pluginId = self.prompt.pluginId?.trimmedNonEmpty {
                rows.append(DetailRow(label: "Plugin", value: pluginId))
            }
            if let severity = self.prompt.pluginSeverity?.trimmedNonEmpty {
                rows.append(DetailRow(label: "Severity", value: severity))
            }
        } else {
            if let host = self.prompt.host?.trimmedNonEmpty {
                rows.append(DetailRow(label: "Runs on", value: host))
            } else if let nodeId = self.prompt.nodeId?.trimmedNonEmpty {
                rows.append(DetailRow(label: "Runs on", value: nodeId))
            }
        }
        if let expires = Self.expiresText(self.prompt.expiresAtMs) {
            rows.append(DetailRow(label: "Answer within", value: expires))
        }
        return rows
    }

    private var resolvedColor: Color {
        switch self.resolvedTone {
        case .success: OpenClawBrand.ok
        case .danger: OpenClawBrand.danger
        case .warning: OpenClawBrand.warn
        case .neutral, nil: SimplePalette.secondaryInk
        }
    }

    private var resolvedSymbol: String {
        switch self.resolvedTone {
        case .success: "checkmark.circle.fill"
        case .danger: "xmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .neutral, nil: "info.circle.fill"
        }
    }

    static func expiresText(_ expiresAtMs: Int64?, now: Date = .now) -> String? {
        guard let expiresAtMs else { return nil }
        let remaining = Double(expiresAtMs) / 1000 - now.timeIntervalSince1970
        guard remaining > 0 else { return String(localized: "Expired") }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = remaining < 60 ? [.second] : (remaining < 3600 ? [.minute] : [.hour])
        return formatter.string(from: remaining.rounded(.up))
    }
}

#if DEBUG
/// `--openclaw-simple-approval-sample` shows the card over the simple layout
/// with a sample exec request, so screenshots can cover it without a gateway
/// fixture. Decisions only dismiss the sample.
struct SimpleApprovalSampleOverlay: View {
    @Environment(NodeAppModel.self) private var appModel
    @State private var isVisible = true

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--openclaw-simple-approval-sample")
    }

    var body: some View {
        if self.isVisible, let prompt = Self.samplePrompt() {
            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                SimpleApprovalCard(
                    prompt: prompt,
                    agentName: SimpleAgentIdentity.displayName(appModel: self.appModel),
                    isResolving: false,
                    canDismiss: true,
                    errorText: nil,
                    resolvedText: nil,
                    resolvedTone: nil,
                    onDecision: { _ in self.isVisible = false },
                    onCancel: { self.isVisible = false })
                    .frame(maxHeight: 680)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 460)
            }
        }
    }

    private static func samplePrompt() -> NodeAppModel.ExecApprovalPrompt? {
        let payload: [String: Any] = [
            "id": "simple-approval-sample",
            "kind": "exec",
            "gatewayStableID": "simple-approval-sample",
            "commandText": "brew upgrade --cask firefox",
            "allowedDecisions": ["allow-once", "allow-always", "deny"],
            "host": "Mac mini",
            "agentId": "main",
            "expiresAtMs": Int64((Date.now.timeIntervalSince1970 + 300) * 1000),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return try? JSONDecoder().decode(NodeAppModel.ExecApprovalPrompt.self, from: data)
    }
}
#endif
