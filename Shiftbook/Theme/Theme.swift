import SwiftUI
import UIKit

// "Time Card" design language.
// Green = money earned / on shift. Coral = money spent. Amber = overtime, breaks, streaks.
// Every color has a light and a dark version.

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

enum Theme {
    static let paper = Color(light: 0xF1F4F1, dark: 0x0E1412)
    static let card = Color(light: 0xFFFFFF, dark: 0x18201C)
    static let ink = Color(light: 0x16201B, dark: 0xE7EDE9)
    static let muted = Color(light: 0x5C6761, dark: 0x93A199)
    static let line = Color(light: 0xDAE0DB, dark: 0x28322D)
    static let sunk = Color(light: 0xE6EBE7, dark: 0x202A25)

    static let green = Color(light: 0x127A55, dark: 0x3DC38A)
    static let greenSoft = Color(light: 0xDCEFE5, dark: 0x16362A)
    static let coral = Color(light: 0xC94B37, dark: 0xF07B64)
    static let coralSoft = Color(light: 0xF8E1DB, dark: 0x3D211B)
    static let amber = Color(light: 0xAD6707, dark: 0xEEA23C)
    static let amberSoft = Color(light: 0xF9EAD1, dark: 0x3A2B13)

    static let catBlue = Color(light: 0x2F5BB8, dark: 0x6F95EA)
    static let catGrey = Color(light: 0x6E7C74, dark: 0x94A39B)
    static let catPurple = Color(light: 0x8A4FB0, dark: 0xB888DA)

    /// Text placed on an ink-colored button.
    static let onInk = Color(light: 0xF1F4F1, dark: 0x0E1412)
}

/// Bricolage Grotesque for titles, Figtree for text, DM Mono for every time and money amount.
/// If a font file is missing, SwiftUI falls back to the system font, so nothing crashes.
enum AppFont {
    enum Weight { case regular, medium, semibold, bold }

    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("BricolageGrotesque-ExtraBold", size: size, relativeTo: style)
    }

    static func displayBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("BricolageGrotesque-Bold", size: size, relativeTo: style)
    }

    static func text(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .regular: name = "Figtree-Regular"
        case .medium: name = "Figtree-Medium"
        case .semibold: name = "Figtree-SemiBold"
        case .bold: name = "Figtree-Bold"
        }
        return .custom(name, size: size, relativeTo: style)
    }

    static func num(_ size: CGFloat, medium: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(medium ? "DMMono-Medium" : "DMMono-Regular", size: size, relativeTo: style)
    }
}
