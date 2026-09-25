import SwiftUI

// MARK: - The field

/// The continuous, page-level light field. One instance sits behind the
/// whole window, never behind a single section. Operate mode: the field
/// recedes, so it is static (no bloom drift, no grain).
struct LitField: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = max(w, h)
            ZStack {
                // linear-gradient(140deg, #dbe3e7, #e9e6df 46%, #f7e6d4)
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0xDBE3E7), location: 0),
                        .init(color: Color(hex: 0xE9E6DF), location: 0.46),
                        .init(color: Color(hex: 0xF7E6D4), location: 1),
                    ],
                    startPoint: UnitPoint(x: 0.18, y: 0),
                    endPoint: UnitPoint(x: 0.82, y: 1)
                )
                lobe(0xB9C8D2, at: UnitPoint(x: 0.06, y: 0.10), radius: r * 0.62) // cool
                lobe(0xFFD9B8, at: UnitPoint(x: 0.90, y: 0.14), radius: r * 0.48) // warm
                lobe(0xFFCFA8, at: UnitPoint(x: 0.76, y: 0.92), radius: r * 0.42) // ember
                lobe(0xCFD8D6, at: UnitPoint(x: 0.26, y: 0.84), radius: r * 0.55) // haze
            }
        }
        .background(AppColor.base)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func lobe(_ hex: UInt32, at center: UnitPoint, radius: CGFloat) -> some View {
        RadialGradient(
            stops: [
                .init(color: Color(hex: hex), location: 0),
                .init(color: Color(hex: hex).opacity(0), location: 0.62),
            ],
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    }
}

// MARK: - Depth

/// The lift ladder. Depth is a lit top edge plus a short, offset contact
/// shadow. Never a hairline outline plus a wide halo.
enum LitLift {
    case one, two, three
}

extension View {
    /// Veiled panel: white veil over the field, lit top edge, contact shadow.
    /// No perimeter stroke.
    func litPanel(strong: Bool = false,
                  lift: LitLift = .one,
                  radius: CGFloat = AppMetric.radiusPanel) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(strong ? AppColor.veilStrong : AppColor.veil, in: shape)
            .litLift(lift, in: shape)
    }

    /// `--edge` highlight plus one step of the contact-shadow ladder.
    func litLift<S: Shape>(_ tier: LitLift, in shape: S) -> some View {
        modifier(LitLiftModifier(tier: tier, shape: shape))
    }
}

private struct LitLiftModifier<S: Shape>: ViewModifier {
    var tier: LitLift
    var shape: S

    // rgba(16, 20, 28, a) from the shadow vocabulary
    private func shade(_ a: Double) -> Color {
        Color(.sRGB, red: 16 / 255, green: 20 / 255, blue: 28 / 255, opacity: a)
    }

    func body(content: Content) -> some View {
        let lit = content
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.9)).frame(height: 1)
            }
            .clipShape(shape)

        switch tier {
        case .one:
            lit
                .shadow(color: shade(0.05), radius: 0.5, x: 0, y: 1)
                .shadow(color: shade(0.18), radius: 4, x: 0, y: 3)
        case .two:
            lit
                .shadow(color: shade(0.06), radius: 1, x: 0, y: 1)
                .shadow(color: shade(0.22), radius: 8, x: 0, y: 6)
        case .three:
            lit
                .shadow(color: shade(0.07), radius: 1.5, x: 0, y: 2)
                .shadow(color: shade(0.26), radius: 14, x: 0, y: 11)
        }
    }
}

// MARK: - Dividers

/// Internal divider at `hair`. Inside panels only.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(AppColor.hair).frame(height: 1)
    }
}
