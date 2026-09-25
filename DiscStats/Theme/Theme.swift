import SwiftUI
import AppKit

/// Lit Field design system (ihnatov.nl `DESIGN.md`), applied in Operate mode.
///
/// Rules this file encodes:
///   - One chroma. `accent` (#FF4726) is for fills and for marks on night.
///     `accentOnLight` (#C03210) is the only accent legal for text or icons
///     on a light ground. Never put `accent` text on light.
///   - Ink on accent fills, never white (white on #FF4726 is 3.38:1).
///   - Two faces: Archivo for controls, numbers and headings; Schibsted
///     Grotesk for sentences. Monospace only for real data (file paths).
///   - Status colours are functional only, never decoration.
///   - The app is light-only: the palette is a light field, so the window
///     forces `.light` (see DiscStatsApp).

// MARK: - Palette

enum AppColor {
    // The field
    static let base     = Color(hex: 0xECEEED)
    static let baseDeep = Color(hex: 0xE2E6E6)

    // Ink, four steps. Do not add a fifth.
    static let ink  = Color(hex: 0x0B0C0E)
    static let ink2 = Color(hex: 0x23262B)
    static let ink3 = Color(hex: 0x454A52)
    static let ink4 = Color(hex: 0x5C626B)

    // Accent (Two-Oranges Rule)
    static let accent        = Color(hex: 0xFF4726)
    static let accentOnLight = Color(hex: 0xC03210)

    // Night, a component-level inversion only
    static let night    = Color(hex: 0x0B0C0E)
    static let night2   = Color(hex: 0x16181C)
    static let onNight  = Color(hex: 0xF4F5F5)
    static let onNight2 = Color(hex: 0xA9B0B8)

    // Veils, Operate-mode opacity (0.72 to 0.84 over a working surface)
    static let veil       = Color.white.opacity(0.78)
    static let veilStrong = Color.white.opacity(0.88)

    // Hairlines: internal dividers and chip outlines only, never a panel edge
    static let hair       = ink.opacity(0.12)
    static let hairStrong = ink.opacity(0.22)

    // Form controls (Operate-only tokens)
    static let controlBorder       = Color(hex: 0x7A8188) // 3.67:1 on veil
    static let controlBorderStrong = Color(hex: 0x4A5158)
    static let controlDisabledInk  = Color(hex: 0x8B9197)

    // Status, functional only
    static let statusError   = Color(hex: 0x9F1239)
    static let statusSuccess = Color(hex: 0x0F5D3A)
    static let statusWarning = Color(hex: 0x7A4B00)
    static let statusInfo    = Color(hex: 0x14507A)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Typography

/// Bundled cuts (Resources/Fonts, SIL OFL): Archivo 600/700 and Schibsted
/// Grotesk 400/700. PostScript names are read from the files themselves;
/// Archivo's family is internally "Archivo Roman". Falls back to the system
/// face when a cut is missing, so a broken bundle degrades instead of
/// rendering nothing.
enum AppFont {
    private static let displaySemiboldPS = "ArchivoRoman-SemiBold"
    private static let displayBoldPS     = "ArchivoRoman-Bold"
    private static let textRegularPS     = "SchibstedGrotesk-Regular"
    private static let textBoldPS        = "SchibstedGrotesk-Bold"

    /// Archivo: headings, controls, labels, figures.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let bold = weight == .bold || weight == .heavy || weight == .black
        let name = bold ? displayBoldPS : displaySemiboldPS
        if isAvailable(name) { return .custom(name, size: size) }
        return .system(size: size, weight: weight)
    }

    /// Schibsted Grotesk: anything that reads as a sentence.
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .regular ? textRegularPS : textBoldPS
        if isAvailable(name) { return .custom(name, size: size) }
        return .system(size: size, weight: weight)
    }

    private static var cache: [String: Bool] = [:]
    private static func isAvailable(_ name: String) -> Bool {
        if let hit = cache[name] { return hit }
        let ok = NSFont(name: name, size: 12) != nil
        cache[name] = ok
        return ok
    }
}

// MARK: - Metrics

enum AppMetric {
    static let xs: CGFloat = 4
    static let s:  CGFloat = 8
    static let m:  CGFloat = 12
    static let l:  CGFloat = 16
    static let xl: CGFloat = 24

    // Operate-mode radii: controls 10, panels 14 to 16, pills 999
    static let radiusControl: CGFloat = 10
    static let radiusPanel:   CGFloat = 14

    // Density
    static let controlCompact:     CGFloat = 36
    static let controlComfortable: CGFloat = 44
    static let pillMinHeight:      CGFloat = 48
}
