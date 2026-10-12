import SwiftUI

// SIMPLE-UI: "More" — every classic OpenClaw destination, grouped and described
// in plain language. Each opens as a sheet so the main shell stays simple.

struct SimpleMoreScreen: View {
    typealias Destination = RootTabs.SidebarDestination

    struct Item: Identifiable {
        let destination: Destination
        let title: String
        let subtitle: String
        let systemImage: String
        let tint: Color

        var id: String {
            self.destination.id
        }
    }

    struct ItemGroup: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let items: [Item]
    }

    let open: (Destination) -> Void
    let useClassicInterface: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SimpleLargeTitle("More")
                ForEach(Self.groups) { group in
                    Text(group.title)
                        .font(OpenClawType.footnoteSemiBold)
                        .foregroundStyle(SimplePalette.secondaryInk)
                        .textCase(.uppercase)
                        .padding(.horizontal, SimpleMetric.gutter + 4)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(group.items) { item in
                            Button {
                                self.open(item.destination)
                            } label: {
                                SimpleMoreRow(item: item)
                            }
                            .buttonStyle(SimpleRowButtonStyle())
                            .accessibilityIdentifier("Simple.More.\(item.destination.rawValue)")
                            if item.id != group.items.last?.id {
                                SimpleRowDivider(leadingInset: 16 + 36 + 14)
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
                }
                Button(action: self.useClassicInterface) {
                    Text("Use classic interface")
                        .font(OpenClawType.subheadMedium)
                        .foregroundStyle(SimplePalette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
                .accessibilityHint(
                    Text("Switches to the sidebar layout. Tap the sparkles button in its footer to come back."))
                .accessibilityIdentifier("Simple.More.UseClassic")
            }
            .padding(.bottom, SimpleMetric.scrollBottomPadding)
        }
        .scrollIndicators(.hidden)
        .simpleCanvas()
    }

    static var groups: [ItemGroup] {
        [
            ItemGroup(id: "agent", title: "Your agent", items: [
                Item(
                    destination: .agents,
                    title: String(localized: "Agents"),
                    subtitle: String(localized: "Who's on your team and what they run on"),
                    systemImage: "person.2.fill",
                    tint: SimplePalette.Tint.blue),
                Item(
                    destination: .sessions,
                    title: String(localized: "All chats"),
                    subtitle: String(localized: "Every conversation, including channels"),
                    systemImage: "bubble.left.and.bubble.right.fill",
                    tint: SimplePalette.Tint.teal),
                Item(
                    destination: .activity,
                    title: String(localized: "Activity"),
                    subtitle: String(localized: "What your agent did and when"),
                    systemImage: "waveform.path.ecg",
                    tint: SimplePalette.Tint.pink),
                Item(
                    destination: .dreaming,
                    title: String(localized: "Dreaming"),
                    subtitle: String(localized: "How your agent reflects on and tidies its memory"),
                    systemImage: "moon.stars.fill",
                    tint: SimplePalette.Tint.indigo),
            ]),
            ItemGroup(id: "automation", title: "Automation & skills", items: [
                Item(
                    destination: .cron,
                    title: String(localized: "Automations"),
                    subtitle: String(localized: "Schedules and recurring check-ins"),
                    systemImage: "timer",
                    tint: SimplePalette.Tint.orange),
                Item(
                    destination: .skillWorkshop,
                    title: String(localized: "Skills"),
                    subtitle: String(localized: "Teach your agent new abilities"),
                    systemImage: "hammer.fill",
                    tint: SimplePalette.Tint.brown),
                Item(
                    destination: .workboard,
                    title: String(localized: "Workboard"),
                    subtitle: String(localized: "Projects and longer-running work"),
                    systemImage: "folder.fill",
                    tint: SimplePalette.Tint.cyan),
            ]),
            ItemGroup(id: "devices", title: "Devices", items: [
                Item(
                    destination: .instances,
                    title: String(localized: "Devices"),
                    subtitle: String(localized: "Phones, computers, and nodes you've paired"),
                    systemImage: "iphone.gen3.radiowaves.left.and.right",
                    tint: SimplePalette.Tint.green),
                Item(
                    destination: .desktop,
                    title: String(localized: "Desktop"),
                    subtitle: String(localized: "Watch or take over a computer session"),
                    systemImage: "display",
                    tint: SimplePalette.Tint.gray),
                Item(
                    destination: .terminal,
                    title: String(localized: "Terminal"),
                    subtitle: String(localized: "Command line on your gateway"),
                    systemImage: "terminal.fill",
                    tint: SimplePalette.Tint.gray),
            ]),
            ItemGroup(id: "account", title: "Account", items: [
                Item(
                    destination: .usage,
                    title: String(localized: "Usage"),
                    subtitle: String(localized: "Tokens and spend"),
                    systemImage: "chart.bar.fill",
                    tint: SimplePalette.Tint.purple),
                Item(
                    destination: .overview,
                    title: String(localized: "Dashboard"),
                    subtitle: String(localized: "Everything at a glance"),
                    systemImage: "square.grid.2x2.fill",
                    tint: SimplePalette.Tint.blue),
                Item(
                    destination: .gateway,
                    title: String(localized: "Connection"),
                    subtitle: String(localized: "Your OpenClaw gateway"),
                    systemImage: "antenna.radiowaves.left.and.right",
                    tint: SimplePalette.Tint.green),
                Item(
                    destination: .settings,
                    title: String(localized: "Settings"),
                    subtitle: String(localized: "Permissions, notifications, and more"),
                    systemImage: "gearshape.fill",
                    tint: SimplePalette.Tint.gray),
                Item(
                    destination: .docs,
                    title: String(localized: "Help & docs"),
                    subtitle: String(localized: "Guides for getting more done"),
                    systemImage: "book.fill",
                    tint: SimplePalette.Tint.orange),
            ]),
        ]
    }
}

private struct SimpleMoreRow: View {
    let item: SimpleMoreScreen.Item

    var body: some View {
        HStack(spacing: 14) {
            SimpleIconTile(systemImage: self.item.systemImage, tint: self.item.tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: self.item.title)
                    .font(OpenClawType.body)
                    .foregroundStyle(SimplePalette.ink)
                Text(verbatim: self.item.subtitle)
                    .font(OpenClawType.footnote)
                    .foregroundStyle(SimplePalette.secondaryInk)
                    .lineLimit(2)
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
}
