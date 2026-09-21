import SwiftUI
import UIKit

/// The "Sheet & Ice" theme (v0.8.0) — a curling-flavored look over the
/// standard layout: cool ice-blue surfaces, slate structure, and the classic
/// red/yellow stone handles as accent colors.
///
/// Everything here is chrome only: no layout or behavior changes. The palette
/// is dynamic (light + dark variants), so dark mode works without extra code.
/// Structure stays Apple-clean underneath — a coach glances at this mid-
/// practice, so whimsy lives in the accents, readability in the structure.
enum Theme {
    /// App-wide tint: drives prominent buttons, search, toggles, selection.
    static let tint = Color(light: 0x2E6DB4, dark: 0x5B93D6)

    /// The sheet of ice: the main full-bleed background.
    static let ice = Color(light: 0xF2F7FA, dark: 0x101820)

    /// Slightly deeper ice: navigation/toolbar bars and raised chrome.
    static let iceDeep = Color(light: 0xDCE9F2, dark: 0x182430)

    /// Slate: neutral structure (borders, quiet badges).
    static let slate = Color(light: 0x64788C, dark: 0x8FA3B8)

    /// The two classic stone handles — the fun accents.
    static let stoneRed = Color(light: 0xD2443C, dark: 0xE0554C)
    static let stoneYellow = Color(light: 0xF5B32B, dark: 0xF7C04A)

    /// Granite: the stone body (dark neutral for chips/headers).
    static let granite = Color(light: 0x454C54, dark: 0x5A636D)

    /// The house button: the primary action blue (the big Execute button).
    static let button = Color(light: 0x3A6EA8, dark: 0x4C82C4)
}

/// Sheet & Ice chrome for one screen (v0.8.0), applied to the screen's root
/// content *inside* its NavigationStack (the Group/List/Form):
/// - hides the list/form background and paints the ice behind it,
/// - gives the navigation bar the deeper ice.
///
/// It must be applied inside the stack: on the current SDK the environment
/// behind `scrollContentBackground`/`toolbarBackground` does not flow from
/// *outside* a NavigationStack to its content, so an outer application
/// silently no-ops (verified on iOS 26).
///
/// `scrollContentBackground` and `toolbarBackground` flow through the
/// environment, so pushed destinations of that stack inherit the treatment
/// without their own application.
private struct SheetSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Theme.ice)
            .toolbarBackground(Theme.iceDeep, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    /// The Sheet & Ice surface treatment (v0.8.0) — inside a NavigationStack.
    func sheetSurface() -> some View {
        modifier(SheetSurface())
    }

    /// Full-bleed ice behind a width-framed screen (v0.8.0) — applied as the
    /// outermost modifier, after any `.frame(maxWidth:)`, so the ice covers
    /// the whole window, not just the 480/700pt content column.
    func sheetBackdrop() -> some View {
        background(Theme.ice)
    }

    /// Sheet & Ice for the tab bar (v0.8.0) — applied to the TabView itself.
    func tabBarIce() -> some View {
        self
            .toolbarBackground(Theme.ice, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

// MARK: - Dynamic color plumbing

private extension Color {
    /// A color with separate light and dark variants (hex).
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
