import SwiftUI

struct WaveformOverlayView: View {
    @ObservedObject var controller: VoiceSessionController

    var body: some View {
        HStack(spacing: 14) {
            statusIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if case .failure(let message, _) = controller.phase {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                } else if let notice = controller.notice {
                    Text(notice)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange.opacity(0.9))
                        .lineLimit(1)
                } else if case .recording = controller.phase {
                    waveform
                }
            }
            Spacer(minLength: 4)
            trailingAction
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 17)
        .frame(width: 410, height: 78)
        .background(Color(red: 0.055, green: 0.05, blue: 0.09).opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 16, y: 8)
    }

    private var statusIcon: some View {
        ZStack {
            Circle().fill(iconColor.opacity(0.18))
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(iconColor)
        }
        .frame(width: 42, height: 42)
    }

    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<18, id: \.self) { index in
                let level = max(Double(controller.audioLevel), 0.12)
                let wave = 0.35 + level * (0.45 + 0.15 * Double(index % 3))
                Capsule()
                    .fill(MacVoiceTheme.gradient)
                    .frame(width: 3, height: 4 + 18 * wave)
            }
        }
        .frame(height: 23)
    }

    @ViewBuilder
    private var trailingAction: some View {
        switch controller.phase {
        case .recording:
            Button {
                controller.stopRecording()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        case .failure(_, let canRetry) where canRetry:
            HStack(spacing: 7) {
                Button {
                    controller.retryTranscription()
                } label: {
                    Label(L10n.text("action.retry_short"), systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(MacVoiceTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    controller.discardFailedRecording()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }
        case .failure:
            Button {
                controller.resetPresentation()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }

    private var title: String {
        switch controller.phase {
        case .idle: L10n.text("status.ready")
        case .recording: L10n.text("status.recording")
        case .transcribing: L10n.text("status.transcribing")
        case .success: L10n.text("status.copied")
        case .failure: L10n.text("status.failed")
        }
    }

    private var iconName: String {
        switch controller.phase {
        case .recording: "waveform"
        case .transcribing: "sparkles"
        case .success: "checkmark"
        case .failure: "exclamationmark"
        case .idle: "mic"
        }
    }

    private var iconColor: Color {
        switch controller.phase {
        case .failure: .red
        case .success: .green
        default: MacVoiceTheme.cyan
        }
    }
}
