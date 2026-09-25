import SwiftUI

/// Operate-mode button roles (DESIGN.md Part II, 4.3). Pills throughout.
/// One `.primary` per view; `.accent` is reserved for the single most
/// consequential action on a surface and is not used in this app.
enum LitButtonRole {
    case primary, secondary, ghost, destructive
}

enum LitButtonSize {
    /// 36pt, data-dense views and toolbars
    case compact
    /// 44pt, default
    case comfortable
    /// 48pt pill, the one standalone call to action
    case large
}

struct LitButtonStyle: ButtonStyle {
    var role: LitButtonRole
    var size: LitButtonSize = .comfortable

    func makeBody(configuration: Configuration) -> some View {
        LitButtonBody(configuration: configuration, role: role, size: size)
    }
}

extension ButtonStyle where Self == LitButtonStyle {
    static func lit(_ role: LitButtonRole, size: LitButtonSize = .comfortable) -> LitButtonStyle {
        LitButtonStyle(role: role, size: size)
    }
}

private struct LitButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let role: LitButtonRole
    let size: LitButtonSize

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(AppFont.display(fontSize, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: minHeight)
            .background { background }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .offset(y: hovering && isEnabled && role == .primary && !reduceMotion ? -1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
            .onHover { hovering = $0 }
    }

    private var fontSize: CGFloat {
        switch size {
        case .compact: return 13.5
        case .comfortable: return 14.5
        case .large: return 15
        }
    }

    private var minHeight: CGFloat {
        switch size {
        case .compact: return AppMetric.controlCompact
        case .comfortable: return AppMetric.controlComfortable
        case .large: return AppMetric.pillMinHeight
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .compact: return 12
        case .comfortable: return 16
        case .large: return 20
        }
    }

    @ViewBuilder private var background: some View {
        switch role {
        case .primary:
            Capsule()
                .fill(isEnabled ? (hovering ? AppColor.night2 : AppColor.night)
                                : AppColor.controlDisabledInk)
                .litLift(hovering && isEnabled ? .two : .one, in: Capsule())
        case .secondary:
            Capsule()
                .fill(Color.white.opacity(hovering && isEnabled ? 0.8 : 0.6))
                .overlay(Capsule().strokeBorder(
                    hovering && isEnabled ? AppColor.controlBorderStrong : AppColor.controlBorder,
                    lineWidth: 1))
        case .ghost:
            Capsule()
                .fill(Color.white.opacity(hovering && isEnabled ? 0.55 : 0))
        case .destructive:
            Capsule()
                .fill(AppColor.statusError.opacity(hovering && isEnabled ? 0.08 : 0))
                .overlay(Capsule().strokeBorder(
                    isEnabled ? AppColor.statusError : AppColor.controlDisabledInk,
                    lineWidth: 1))
        }
    }

    private var foreground: Color {
        guard isEnabled else {
            return role == .primary ? AppColor.onNight : AppColor.controlDisabledInk
        }
        switch role {
        case .primary:     return AppColor.onNight
        case .secondary:   return AppColor.ink
        case .ghost:       return hovering ? AppColor.ink : AppColor.ink2
        case .destructive: return AppColor.statusError
        }
    }
}
