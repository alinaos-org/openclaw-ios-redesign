import OpenClawChatUI
import SwiftUI
import UIKit

// SIMPLE-UI: First-run screens for the simple layout: what your agent is, how
// to connect this iPhone to it, and a hello once it's connected. Each one
// stands in for one of the wizard's full-screen steps and calls that step's
// own actions, so `OnboardingWizardView` still owns scanning, setup codes,
// pairing, the manual and recovery steps, and completion.

extension EnvironmentValues {
    /// Set by `RootTabs` while the simple layout is active.
    @Entry var usesSimpleOnboarding = false
}

/// The three screens in order, for the progress dots.
enum SimpleOnboardingStage: Int, CaseIterable {
    case welcome
    case connect
    case ready
}

/// Step 1: what your agent is, and what connecting it allows. The trust note
/// sits right under the title so it stays above the pinned button on small
/// phones and at large text sizes.
struct SimpleOnboardingWelcome: View {
    let step: OnboardingIntroStep

    var body: some View {
        SimpleOnboardingPage(stage: .welcome) {
            SimpleOnboardingHero(
                mood: .happy,
                title: Text("Meet your agent"),
                subtitle: Text("A personal AI that gets things done for you, running on your own computer."))

            SimpleOnboardingTrustNote()
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 20) {
                SimpleOnboardingPoint(
                    systemImage: "desktopcomputer",
                    tint: SimplePalette.Tint.blue,
                    title: Text("Lives on your computer"),
                    detail: Text("It keeps working there, even while your phone is in your pocket."))
                SimpleOnboardingPoint(
                    systemImage: "bubble.left.and.bubble.right.fill",
                    tint: SimplePalette.Tint.green,
                    title: Text("Chat or talk"),
                    detail: Text("Type a message or tap the mic to ask for anything."))
                SimpleOnboardingPoint(
                    systemImage: "hand.raised.fill",
                    tint: SimplePalette.Tint.orange,
                    title: Text("You stay in charge"),
                    detail: Text("Approve or deny what it asks to do, right from this iPhone."))
            }
            .padding(.top, 28)
        } actions: {
            SimpleOnboardingPrimaryButton(identifier: "simple-onboarding-start", action: self.step.onContinue) {
                Text("Get started")
            }
        }
    }
}

/// Step 2: run one command on the computer, then scan the code it shows.
struct SimpleOnboardingConnect: View {
    let step: OnboardingWelcomeStep

    private static let setupGuide = URL(string: "https://docs.openclaw.ai")

    var body: some View {
        let status = self.step.statusLine.trimmingCharacters(in: .whitespacesAndNewlines)

        SimpleOnboardingPage(stage: .connect) {
            SimpleOnboardingHero(
                mood: self.step.isConnecting ? .thinking : .curious,
                title: Text("Connect to your computer"),
                subtitle: Text("Pair this iPhone with the computer your agent runs on."))

            VStack(alignment: .leading, spacing: 18) {
                SimpleOnboardingNumberedStep(number: 1) {
                    Text("On your computer, run this in a terminal:")
                        .font(OpenClawType.subhead)
                        .foregroundStyle(SimplePalette.ink)
                    SimpleOnboardingCommand(command: "openclaw qr")
                }
                SimpleOnboardingNumberedStep(number: 2) {
                    Text("Tap Scan code and point your camera at the code it shows.")
                        .font(OpenClawType.subhead)
                        .foregroundStyle(SimplePalette.ink)
                }
            }
            .simpleOnboardingCard()
            .padding(.top, 32)

            if !status.isEmpty {
                Text(verbatim: status)
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .transition(.opacity)
                    .accessibilityIdentifier("simple-onboarding-status")
            }

            if let guide = Self.setupGuide {
                Link(destination: guide) {
                    Text("New to OpenClaw? Set it up on your computer first")
                        .font(OpenClawType.footnoteSemiBold)
                        .foregroundStyle(SimplePalette.accent)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .accessibilityHint(Text("Opens the OpenClaw setup guide"))
            }
        } actions: {
            SimpleOnboardingPrimaryButton(
                identifier: "simple-onboarding-scan",
                isEnabled: !self.step.isConnecting,
                action: self.step.onScanQRCode)
            {
                if self.step.isConnecting {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Connecting…")
                    }
                } else {
                    Label {
                        Text("Scan code")
                    } icon: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
            }

            Button(action: self.step.onManualSetup) {
                Text("Enter a setup code or address")
                    .font(OpenClawType.subheadSemiBold)
                    .foregroundStyle(SimplePalette.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(self.step.isConnecting)
            .accessibilityIdentifier("simple-onboarding-other-ways")
        }
        .animation(.smooth(duration: 0.18), value: status)
    }
}

/// Step 3: say hello to the agent once this iPhone is connected, with a short
/// tour of the tabs it lands on.
struct SimpleOnboardingReady: View {
    @Environment(NodeAppModel.self) private var appModel
    let step: OnboardingSuccessStep

    var body: some View {
        SimpleOnboardingPage(stage: .ready) {
            SimpleOnboardingHero(
                mood: .celebrating,
                title: self.title,
                subtitle: Text("Your agent is connected and ready to help."))

            HStack(spacing: 12) {
                SimpleIconTile(systemImage: "desktopcomputer", tint: SimplePalette.tracking, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected to \(self.step.gatewayName)")
                        .font(OpenClawType.subheadSemiBold)
                        .foregroundStyle(SimplePalette.ink)
                    if let address = self.step.gatewayAddress, !address.isEmpty {
                        Text(verbatim: address)
                            .font(OpenClawType.footnote)
                            .foregroundStyle(SimplePalette.secondaryInk)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SimplePalette.tracking)
                    .accessibilityHidden(true)
            }
            .simpleOnboardingCard()
            .accessibilityElement(children: .combine)
            .padding(.top, 32)

            VStack(alignment: .leading, spacing: 18) {
                Text("Where to start")
                    .font(OpenClawType.footnoteSemiBold)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .accessibilityAddTraits(.isHeader)
                SimpleOnboardingPoint(
                    systemImage: SimpleTab.chat.systemImage,
                    tint: SimplePalette.accent,
                    title: Text("Chat"),
                    detail: Text("Ask for anything. Type, or tap the mic and talk."))
                SimpleOnboardingPoint(
                    systemImage: SimpleTab.ideas.systemImage,
                    tint: SimplePalette.Tint.orange,
                    title: Text("Ideas"),
                    detail: Text("Things your agent can take on for you. Tap one to start."))
                SimpleOnboardingPoint(
                    systemImage: SimpleTab.goals.systemImage,
                    tint: SimplePalette.Tint.green,
                    title: Text("Goals"),
                    detail: Text("Routines and check-ins it keeps track of for you."))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 32)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("simple-onboarding-tour")
        } actions: {
            SimpleOnboardingPrimaryButton(identifier: "simple-onboarding-done", action: self.step.onGetStarted) {
                Text("Start chatting")
            }
        }
    }

    private var title: Text {
        if let name = SimpleAgentIdentity.givenName(appModel: self.appModel) {
            return Text("Say hi to \(name)")
        }
        return Text("Say hi to your agent")
    }
}

// MARK: - Building blocks

/// Readable column width for the onboarding pages on wide screens.
private let simpleOnboardingMaxWidth: CGFloat = 440

/// A scrolling page with progress dots on top and its buttons pinned within
/// thumb reach. The wizard draws the close button in the top-leading corner.
private struct SimpleOnboardingPage<Content: View, Actions: View>: View {
    let stage: SimpleOnboardingStage
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                self.content
            }
            .frame(maxWidth: simpleOnboardingMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 72)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                self.actions
            }
            .frame(maxWidth: simpleOnboardingMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(SimplePalette.canvas)
        }
        .overlay(alignment: .top) {
            SimpleOnboardingProgress(stage: self.stage)
                .frame(height: SimpleMetric.circleButtonSize)
                .padding(.top, 10)
        }
        .simpleCanvas()
        .tint(SimplePalette.accent)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct SimpleOnboardingProgress: View {
    let stage: SimpleOnboardingStage

    var body: some View {
        HStack(spacing: 6) {
            ForEach(SimpleOnboardingStage.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == self.stage ? SimplePalette.accent : SimplePalette.tertiaryInk.opacity(0.4))
                    .frame(width: item == self.stage ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(self.stage.rawValue + 1) of \(SimpleOnboardingStage.allCases.count)"))
    }
}

private struct SimpleOnboardingHero: View {
    let mood: OpenClawMascotMood
    let title: Text
    let subtitle: Text

    var body: some View {
        VStack(spacing: 16) {
            OpenClawMascotView(mood: self.mood, interactive: true)
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                self.title
                    .font(OpenClawType.title1)
                    .foregroundStyle(SimplePalette.ink)
                    .accessibilityAddTraits(.isHeader)
                self.subtitle
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.secondaryInk)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SimpleOnboardingPoint: View {
    let systemImage: String
    let tint: Color
    let title: Text
    let detail: Text

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SimpleIconTile(systemImage: self.systemImage, tint: self.tint, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                self.title
                    .font(OpenClawType.subheadSemiBold)
                    .foregroundStyle(SimplePalette.ink)
                self.detail
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The intro's security notice in plain words: what a connected agent can
/// reach, and to connect only to one you trust.
private struct SimpleOnboardingTrustNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(SimplePalette.attention)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect only to an agent you trust")
                    .font(OpenClawType.subheadSemiBold)
                    .foregroundStyle(SimplePalette.ink)
                Text("""
                Once connected, it can use the iPhone features you turn on, like the camera, \
                microphone, photos, contacts, calendar, and location.
                """)
                .font(OpenClawType.footnote)
                .foregroundStyle(SimplePalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .simpleOnboardingCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("simple-onboarding-trust")
    }
}

private struct SimpleOnboardingNumberedStep<Content: View>: View {
    let number: Int
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: "\(self.number)")
                .font(OpenClawType.footnoteSemiBold)
                .foregroundStyle(SimplePalette.accent)
                .frame(width: 26, height: 26)
                .background(Circle().fill(SimplePalette.accentTint))
            VStack(alignment: .leading, spacing: 10) {
                self.content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 3)
        }
    }
}

/// The setup command, copied with one tap.
private struct SimpleOnboardingCommand: View {
    let command: String
    @State private var didCopy = false

    var body: some View {
        Button(action: self.copy) {
            HStack(spacing: 10) {
                Text(verbatim: self.command)
                    .font(OpenClawType.mono)
                    .foregroundStyle(SimplePalette.ink)
                Spacer(minLength: 0)
                Image(systemName: self.didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(self.didCopy ? SimplePalette.tracking : SimplePalette.accent)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SimplePalette.fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Copy setup code command"))
        .accessibilityValue(self.didCopy ? Text("Copied") : Text(verbatim: self.command))
        .accessibilityIdentifier("simple-onboarding-copy-command")
    }

    private func copy() {
        UIPasteboard.general.string = self.command
        withAnimation(.smooth(duration: 0.14)) {
            self.didCopy = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.smooth(duration: 0.16)) {
                self.didCopy = false
            }
        }
    }
}

private struct SimpleOnboardingPrimaryButton<Title: View>: View {
    let identifier: String
    var isEnabled = true
    let action: () -> Void
    @ViewBuilder let title: Title

    var body: some View {
        Button(action: self.action) {
            self.title
                .font(OpenClawType.subheadSemiBold)
                .foregroundStyle(Color.white)
                .tint(Color.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(SimplePalette.accent))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!self.isEnabled)
        .accessibilityIdentifier(self.identifier)
    }
}

extension View {
    fileprivate func simpleOnboardingCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                    .fill(SimplePalette.surface))
            .overlay(
                RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                    .stroke(SimplePalette.hairline, lineWidth: 0.5))
    }
}
