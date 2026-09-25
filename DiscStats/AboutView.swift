import SwiftUI

struct AboutView: View {
    private let appVersion: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(v) (\(b))"
    }()

    var body: some View {
        VStack(spacing: AppMetric.l) {
            // App mark: a night tile with an accent glyph (5.76:1). Flat
            // fill, lit edge and a short contact shadow; no gradient, no halo.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColor.night)
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "internaldrive")
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(AppColor.accent)
                )
                .litLift(.two, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)
                .padding(.top, AppMetric.xs)

            VStack(spacing: AppMetric.xs) {
                Text("DiscStats")
                    .font(AppFont.display(26, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(AppColor.ink)
                Text(appVersion)
                    .font(AppFont.display(13).monospacedDigit())
                    .foregroundStyle(AppColor.ink3)
            }

            Text("A small, native Mac app that scans a folder and shows where your disk space is going. Each rectangle is a file or folder, sized by how much space it takes up. Double-click a folder to drill in, then move what you don’t need to the Trash.")
                .font(AppFont.text(14))
                .foregroundStyle(AppColor.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppMetric.s)

            Hairline().padding(.horizontal, AppMetric.xl)

            VStack(spacing: 6) {
                Text("Made by Yuri Ihnatov")
                    .font(AppFont.text(14))
                    .foregroundStyle(AppColor.ink2)
                Link(destination: URL(string: "https://ihnatov.nl")!) {
                    Text("ihnatov.nl")
                        .font(AppFont.display(14))
                        .underline(true, color: AppColor.hairStrong)
                        .foregroundStyle(AppColor.accentOnLight)
                }
                .buttonStyle(.plain)
                .pointerStyleLinkIfAvailable()
                .help("Open ihnatov.nl in your browser")
            }

            Text("© \(currentYear) Yuri Ihnatov")
                .font(AppFont.text(12).monospacedDigit())
                .foregroundStyle(AppColor.ink4)
                .padding(.top, 2)
        }
        .padding(28)
        .frame(width: 380)
        .background(LitField())
    }

    private var currentYear: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: Date())
    }
}

private extension View {
    @ViewBuilder
    func pointerStyleLinkIfAvailable() -> some View {
        if #available(macOS 15.0, *) {
            self.pointerStyle(.link)
        } else {
            self
        }
    }
}

#Preview {
    AboutView()
}
