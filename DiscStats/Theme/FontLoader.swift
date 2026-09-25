import Foundation
import CoreText

/// Registers every font under Resources/Fonts so `Font.custom` resolves.
/// A bundled TTF is not visible to AppKit until it is registered with the
/// font manager. Called once from `DiscStatsApp.init`.
enum FontLoader {
    static func registerBundledFonts() {
        guard let dir = Bundle.main.resourceURL?
            .appendingPathComponent("Fonts", isDirectory: true),
              let entries = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)
        else { return }
        for url in entries where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
