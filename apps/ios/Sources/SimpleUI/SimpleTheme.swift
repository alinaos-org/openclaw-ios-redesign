import SwiftUI
import UIKit

// SIMPLE-UI: Visual tokens for the simple layout (see SIMPLE_UI.md).
// Kept separate from `OpenClawBrand` so upstream palette changes never
// conflict with the fork.

enum SimplePalette {
    /// Near-white page canvas behind every tab.
    static let canvas = adaptive(light: 0xFAFAFA, dark: 0x181819)
    /// Raised surfaces: header capsule, cards, circular buttons.
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x242426)
    static let ink = adaptive(light: 0x111112, dark: 0xF2F2F3)
    static let secondaryInk = adaptive(light: 0x6B6B70, dark: 0xA1A1A6)
    static let tertiaryInk = adaptive(light: 0x9A9AA0, dark: 0x6E6E73)
    /// The single interactive accent. Readable as text on both canvases.
    static let accent = adaptive(light: 0x0064D4, dark: 0x1793FF)
    static let tabBar = adaptive(light: 0xF9F9F9, dark: 0x202022)
    static let tabSelection = adaptive(light: 0xEBEBEB, dark: 0x38383B)
    /// Quiet fill for secondary buttons (Deny) and inset rows.
    static let fill = adaptive(light: 0xF3F4F6, dark: 0x2C2C2F)
    static let hairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.07)
    })
    static let tracking = adaptive(light: 0x009E39, dark: 0x30D158)
    static let trackingHalo = adaptive(light: 0xCAEAD5, dark: 0x153D24)
    static let paused = adaptive(light: 0x8E8E93, dark: 0x8E8E93)
    static let pausedHalo = adaptive(light: 0xE5E5EA, dark: 0x2C2C2F)
    static let attention = adaptive(light: 0xC2410C, dark: 0xFF9F0A)

    /// Illustration tints for icon tiles (ideas, More rows). Decorative only;
    /// never use them to signal state.
    enum Tint {
        static let orange = adaptive(light: 0xE8590C, dark: 0xFF922B)
        static let blue = adaptive(light: 0x1C7ED6, dark: 0x4DABF7)
        static let green = adaptive(light: 0x2B8A3E, dark: 0x51CF66)
        static let purple = adaptive(light: 0x7048E8, dark: 0x9775FA)
        static let pink = adaptive(light: 0xD6336C, dark: 0xF06595)
        static let teal = adaptive(light: 0x0C8599, dark: 0x3BC9DB)
        static let indigo = adaptive(light: 0x4263EB, dark: 0x748FFC)
        static let red = adaptive(light: 0xE03131, dark: 0xFF6B6B)
        static let brown = adaptive(light: 0x8D6E63, dark: 0xBCAAA4)
        static let gray = adaptive(light: 0x6B6B70, dark: 0xA1A1A6)
        static let cyan = adaptive(light: 0x1098AD, dark: 0x66D9E8)
    }

    /// Light-blue user bubble with dark ink; deep blue with light ink in dark mode.
    /// Resolved from the SwiftUI color scheme rather than UIKit traits, because the
    /// chat derives bubble ink from these components and the app can override its
    /// appearance independently of the system.
    static func userBubble(for colorScheme: ColorScheme) -> Color {
        Color(simpleHex: colorScheme == .dark ? 0x1B3554 : 0xCCE7FF)
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(simpleHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum SimpleMetric {
    static let gutter: CGFloat = 16
    static let cardRadius: CGFloat = 28
    static let rowRadius: CGFloat = 18
    static let iconTileRadius: CGFloat = 12
    static let circleButtonSize: CGFloat = 44
    static let headerAvatarSize: CGFloat = 44
    static let tabBarItemHeight: CGFloat = 52
    static let tabBarMaxWidth: CGFloat = 520
    /// Breathing room under the last row; the tab bar's clearance inset does the rest.
    static let scrollBottomPadding: CGFloat = 16
    /// Room each tab reserves for the floating tab bar: item height, the bar's
    /// 6pt padding on both sides, its 4pt lift, and an 8pt gap above it.
    static let tabBarClearance: CGFloat = 52 + 6 * 2 + 4 + 8
}

extension View {
    /// Soft, diffuse elevation for raised surfaces. Raised surfaces also draw a
    /// `SimplePalette.hairline` stroke so they stay legible in dark mode,
    /// where shadows disappear.
    func simpleFloatingShadow() -> some View {
        self
            .shadow(color: Color.black.opacity(0.07), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    /// Fills the page with the simple-layout canvas, edge to edge.
    func simpleCanvas() -> some View {
        self.background(SimplePalette.canvas.ignoresSafeArea())
    }

    /// Reserves room for the floating tab bar. Apply inside each tab's
    /// `NavigationStack`: an inset applied outside the stack doesn't reliably
    /// reach the content within it.
    func simpleTabBarClearance(_ isTabBarVisible: Bool) -> some View {
        self.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: isTabBarVisible ? SimpleMetric.tabBarClearance : 0)
                .allowsHitTesting(false)
        }
    }
}

extension Color {
    init(simpleHex hex: UInt32) {
        self.init(uiColor: UIColor(simpleHex: hex))
    }
}

extension UIColor {
    convenience init(simpleHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

extension EnvironmentValues {
    /// False for simple-layout tabs that stay mounted but hidden, so they can
    /// pause animation and stop audio.
    @Entry var simpleTabIsActive = true

    /// Accent for the chat action rows and model controls. The classic layout
    /// keeps OpenClaw's red; the simple layout's sheets use its blue.
    @Entry var chatActionMenuAccent = OpenClawBrand.accent
}

/// Whether the simple layout replaces the classic sidebar layout.
///
/// Stored per device so you can flip back to the upstream UI from
/// More → "Use classic interface". Automated launches (any `--openclaw-`
/// launch flag) keep the classic layout by default so upstream UI tests and
/// screenshots keep working.
enum SimpleShellPreference {
    static let storageKey = "ui.simpleShell.enabled"

    static var defaultEnabled: Bool {
        !ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--openclaw-") }
    }

    /// `--openclaw-simple-shell` / `--openclaw-classic-shell` force a shell
    /// regardless of the stored preference.
    static var launchOverride: Bool? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--openclaw-simple-shell") { return true }
        if arguments.contains("--openclaw-classic-shell") { return false }
        return nil
    }
}
