import SwiftUI

enum AppTheme {
    static let pink = Color(red: 0.97, green: 0.72, blue: 0.8)
    static let pinkDeep = Color(red: 0.82, green: 0.28, blue: 0.52)
    static let pinkSoft = Color(red: 0.99, green: 0.94, blue: 0.96)
    static let ink = Color(red: 0.12, green: 0.11, blue: 0.14)
    static let inkMuted = Color(red: 0.45, green: 0.42, blue: 0.48)

    static var windowBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.97, blue: 0.98),
                Color(red: 0.97, green: 0.93, blue: 0.96),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.pinkDeep.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.5 : 0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.pink.opacity(0.55), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.pink.opacity(0.35), lineWidth: 1)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardModifier())
    }
}
