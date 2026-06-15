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
            ShiftingMeshBackground(intensity: 1)
                .blur(radius: 72)
                .opacity(0.72)
        }
        .ignoresSafeArea()
    }
}

struct ShiftingMeshBackground: View {
    var intensity: Double = 1

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let cx = Float(0.5 + 0.14 * sin(t * 0.55))
            let cy = Float(0.5 + 0.12 * cos(t * 0.72))
            let pulse = 0.22 + 0.08 * sin(t * 0.9)
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(cx, cy), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ],
                colors: [
                    MacVoiceTheme.accent.opacity(pulse * intensity),
                    MacVoiceTheme.pink.opacity((pulse + 0.06) * intensity),
                    MacVoiceTheme.cyan.opacity((pulse - 0.02) * intensity),
                    MacVoiceTheme.pink.opacity((pulse + 0.04) * intensity),
                    MacVoiceTheme.accent.opacity((pulse + 0.1) * intensity),
                    MacVoiceTheme.cyan.opacity(pulse * intensity),
                    MacVoiceTheme.cyan.opacity((pulse - 0.04) * intensity),
                    MacVoiceTheme.accent.opacity((pulse + 0.02) * intensity),
                    MacVoiceTheme.pink.opacity((pulse + 0.08) * intensity)
                ]
            )
        }
    }
}

struct PanelPhaseBackground: View {
    let phase: VoiceSessionPhase

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.05, blue: 0.09).opacity(0.86)
            switch phase {
            case .recording:
                recordingGlow
            case .transcribing:
                transcribingGlow
            default:
                idleGlow
            }
        }
    }

    private var recordingGlow: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let shift = sin(t * 1.1) * 0.35
            LinearGradient(
                colors: [
                    MacVoiceTheme.cyan.opacity(0.55 + shift * 0.15),
                    MacVoiceTheme.pink.opacity(0.45),
                    MacVoiceTheme.accent.opacity(0.5 - shift * 0.1)
                ],
                startPoint: UnitPoint(x: 0.1 + shift * 0.2, y: 0),
                endPoint: UnitPoint(x: 0.9 - shift * 0.2, y: 1)
            )
            .blur(radius: 18)
            .opacity(0.75)
        }
    }

    private var transcribingGlow: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees((t * 85).truncatingRemainder(dividingBy: 360))
            AngularGradient(
                colors: [
                    MacVoiceTheme.cyan.opacity(0.15),
                    MacVoiceTheme.accent.opacity(0.55),
                    MacVoiceTheme.cyan.opacity(0.35),
                    MacVoiceTheme.accent.opacity(0.2),
                    MacVoiceTheme.cyan.opacity(0.15)
                ],
                center: .center,
                angle: angle
            )
            .blur(radius: 22)
            .opacity(0.82)
            .overlay {
                TimelineView(.animation) { inner in
                    let phase = inner.date.timeIntervalSinceReferenceDate * 2.4
                    LinearGradient(
                        colors: [
                            .clear,
                            MacVoiceTheme.cyan.opacity(0.35),
                            .clear
                        ],
                        startPoint: UnitPoint(x: -0.4 + (sin(phase) + 1) * 0.7, y: 0.5),
                        endPoint: UnitPoint(x: 0.2 + (sin(phase) + 1) * 0.7, y: 0.5)
                    )
                    .blur(radius: 10)
                }
            }
        }
    }

    private var idleGlow: some View {
        ShiftingMeshBackground(intensity: 0.35)
            .blur(radius: 24)
            .opacity(0.4)
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
