import OpenClawChatUI
import SwiftUI

// SIMPLE-UI: Tapping the agent opens its profile: who it is, what it's doing
// right now (with a stop button), and four shortcuts: Activity,
// Permissions, Upcoming, and Memory.

struct SimpleAgentProfileSheet: View {
    enum Link: String, CaseIterable, Identifiable {
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

        var subtitle: String {
            switch self {
            case .activity: String(localized: "Everything I've worked on")
            case .permissions: String(localized: "What I can do without asking")
            case .upcoming: String(localized: "Scheduled check-ins and reminders")
            case .memory: String(localized: "What I remember about you")
            }
        }

        var systemImage: String {
            switch self {
            case .activity: "list.bullet"
            case .permissions: "checkmark.shield"
            case .upcoming: "clock.badge"
            case .memory: "touchid"
            }
        }
    }

    let onStop: () -> Void
    let onOpen: (Link) -> Void

    @Environment(NodeAppModel.self) private var appModel

    var body: some View {
        let name = SimpleAgentIdentity.displayName(appModel: self.appModel)
        let status = SimpleAgentStatus.resolve(appModel: self.appModel)
        ScrollView {
            VStack(spacing: 0) {
                OpenClawMascotView(floats: true, mood: status.mood, interactive: true)
                    .frame(width: 120, height: 120)
                    .padding(.top, 28)
                    .accessibilityHidden(true)
                Text(verbatim: name)
                    .font(OpenClawType.title2SemiBold)
                    .foregroundStyle(SimplePalette.ink)
                    .padding(.top, 10)
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
                VStack(spacing: 0) {
                    ForEach(Link.allCases) { link in
                        Button {
                            self.onOpen(link)
                        } label: {
                            HStack(spacing: 14) {
                                SimpleIconTile(systemImage: link.systemImage, tint: SimplePalette.ink, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: link.title)
                                        .font(OpenClawType.headline)
                                        .foregroundStyle(SimplePalette.ink)
                                    Text(verbatim: link.subtitle)
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
                            .padding(.vertical, 12)
                            .accessibilityElement(children: .combine)
                        }
                        .buttonStyle(SimpleRowButtonStyle())
                        .accessibilityIdentifier("Simple.Profile.\(link.rawValue)")
                        if link != Link.allCases.last {
                            SimpleRowDivider(leadingInset: 16 + 40 + 14)
                        }
                    }
                }
                .background(SimplePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SimpleMetric.rowRadius, style: .continuous)
                        .stroke(SimplePalette.hairline, lineWidth: 0.5)
                }
                .padding(.horizontal, SimpleMetric.gutter)
                .padding(.top, 28)
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .simpleCanvas()
        // Tall enough for all four shortcuts at default text size.
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(SimpleMetric.cardRadius)
    }
}
