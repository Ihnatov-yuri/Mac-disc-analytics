import SwiftUI

@main
struct DiscStatsApp: App {
    init() {
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .litChrome()
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
        }

        Window("About DiscStats", id: "about") {
            AboutView()
                .litChrome()
        }
        .windowResizability(.contentSize)
    }
}

private extension View {
    /// Lit Field is a light world: pin the appearance so native chrome
    /// (alerts, scrollers, progress) matches the painted field, and route
    /// the system tint through the light-ground accent.
    func litChrome() -> some View {
        self
            .preferredColorScheme(.light)
            .tint(AppColor.accentOnLight)
    }
}

private struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("About DiscStats") {
            openWindow(id: "about")
        }
    }
}
