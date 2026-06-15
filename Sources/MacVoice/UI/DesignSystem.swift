import SwiftUI

enum MacVoiceTheme {
    static let accent = Color(red: 0.48, green: 0.37, blue: 1.0)
    static let cyan = Color(red: 0.19, green: 0.78, blue: 0.96)
    static let pink = Color(red: 0.95, green: 0.36, blue: 0.76)
    static let background = Color(red: 0.045, green: 0.047, blue: 0.075)
    static let panel = Color.white.opacity(0.075)
    static let stroke = Color.white.opacity(0.12)
    static let secondaryText = Color.white.opacity(0.62)
    static let gradient = LinearGradient(
        colors: [accent, pink, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            MacVoiceTheme.background
            Circle()
                .fill(MacVoiceTheme.accent.opacity(0.28))
                .frame(width: 520)
                .blur(radius: 80)
                .offset(x: -300, y: -240)
            Circle()
                .fill(MacVoiceTheme.cyan.opacity(0.18))
                .frame(width: 420)
                .blur(radius: 72)
                .offset(x: 360, y: 280)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(22)
            .background(MacVoiceTheme.panel.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MacVoiceTheme.stroke, lineWidth: 1)
            }
    }
}

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(MacVoiceTheme.gradient.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.65 : 0.92))
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0.1))
            .clipShape(Capsule())
    }
}
