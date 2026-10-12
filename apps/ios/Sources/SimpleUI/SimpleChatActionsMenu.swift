import OpenClawChatUI
import SwiftUI

// SIMPLE-UI: The chat's ⋯ menu in the simple layout: four everyday actions.
// Model tuning, sign-in, and session options live one level down in
// `SimpleModelSettingsSheet`, so nothing from the classic menu is lost.

struct SimpleChatActionsMenu: View {
    let modelLabel: String?
    let canStartChat: Bool
    let canShare: Bool
    let onNewChat: () -> Void
    let onModelSettings: () -> Void
    let onShare: () -> Void
    let onConnection: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            self.row(
                title: String(localized: "New side chat"),
                systemImage: "square.and.pencil",
                identifier: "simple-actions-new-chat",
                isEnabled: self.canStartChat,
                action: self.onNewChat)
            self.row(
                title: String(localized: "Model & thinking"),
                subtitle: self.modelLabel,
                systemImage: "slider.horizontal.3",
                identifier: "simple-actions-model-settings",
                action: self.onModelSettings)
            self.row(
                title: String(localized: "Share chat"),
                systemImage: "square.and.arrow.up",
                identifier: "simple-actions-share",
                isEnabled: self.canShare,
                action: self.onShare)
            self.row(
                title: String(localized: "Connection"),
                systemImage: "antenna.radiowaves.left.and.right",
                identifier: "simple-actions-connection",
                action: self.onConnection)
        }
        .padding(.vertical, 6)
        .frame(width: 272)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("simple-chat-actions-menu")
    }

    private func row(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        identifier: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(SimplePalette.ink)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: title)
                        .font(OpenClawType.body)
                        .foregroundStyle(SimplePalette.ink)
                    if let subtitle {
                        Text(verbatim: subtitle)
                            .font(OpenClawType.footnote)
                            .foregroundStyle(SimplePalette.secondaryInk)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(SimpleRowButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityIdentifier(identifier)
    }
}

/// Everything the classic ⋯ menu offered beyond the four everyday actions:
/// model, thinking, fast mode, and tool details (OpenClaw's own controls),
/// the reasoning toggle, model sign-in, and session options.
struct SimpleModelSettingsSheet: View {
    @Bindable var viewModel: OpenClawChatViewModel
    let agentModelReference: String?
    @Binding var showsAssistantTrace: Bool
    let canEditSession: Bool
    let canStartWorktreeChat: Bool
    let onSignIn: () -> Void
    let onNewSessionOptions: () -> Void
    let onNewWorktreeChat: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Picking a model or thinking level is the usual reason to be here; close after it.
                    ChatModelControlsMenuItems(
                        viewModel: self.viewModel,
                        agentModelReference: self.agentModelReference)
                    {
                        self.dismiss()
                    }

                    ChatActionMenuSectionHeader(title: String(localized: "Display"))
                    Button {
                        self.showsAssistantTrace.toggle()
                    } label: {
                        ChatActionSystemRow(
                            title: String(localized: "Show reasoning & tool activity"),
                            systemImage: "brain.head.profile",
                            isSelected: self.showsAssistantTrace)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(self.showsAssistantTrace ? .isSelected : [])

                    ChatActionMenuSectionHeader(title: String(localized: "Account"))
                    Button(action: self.onSignIn) {
                        ChatActionSystemRow(
                            title: String(localized: "Sign in to a model provider…"),
                            systemImage: "key")
                    }
                    .buttonStyle(.plain)
                    .disabled(!self.canEditSession)
                    .accessibilityIdentifier("simple-model-sign-in")

                    ChatActionMenuSectionHeader(title: String(localized: "Advanced"))
                    Button(action: self.onNewSessionOptions) {
                        ChatActionSystemRow(
                            title: String(localized: "New session options…"),
                            systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)
                    .disabled(!self.canEditSession)
                    if self.canStartWorktreeChat {
                        Button(action: self.onNewWorktreeChat) {
                            ChatActionSystemRow(
                                title: String(localized: "New chat in worktree"),
                                systemImage: "arrow.triangle.branch")
                        }
                        .buttonStyle(.plain)
                        .disabled(!self.canEditSession)
                    }
                }
                .padding(.vertical, 8)
            }
            .simpleCanvas()
            .environment(\.chatActionMenuAccent, SimplePalette.accent)
            .navigationTitle(Text("Model & thinking"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.dismiss()
                    } label: {
                        Text("Done").font(OpenClawType.subheadSemiBold)
                    }
                    .accessibilityIdentifier("simple-model-settings-done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
