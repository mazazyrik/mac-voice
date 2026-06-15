import AppKit
import SwiftData
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @Query(sort: \TranscriptionRecord.createdAt, order: .reverse)
    private var history: [TranscriptionRecord]

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        if !appModel.voice.lastTranscription.isEmpty {
                            lastTranscription
                        }
                        historySection
                    }
                    .padding(30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(MacVoiceTheme.gradient)
                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            Text("MacVoice")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.08), in: Circle())
            .accessibilityIdentifier("open-settings")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 26)
        .padding(.vertical, 17)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }

    private var hero: some View {
        GlassCard {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(MacVoiceTheme.gradient)
                        .frame(width: 116, height: 116)
                        .scaleEffect(appModel.voice.phase.isActive ? 1.08 : 1)
                        .opacity(appModel.voice.phase.isActive ? 0.5 : 0.18)
                    Button {
                        appModel.voice.toggleRecording()
                    } label: {
                        Image(systemName: heroIcon)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 92, height: 92)
                            .background(MacVoiceTheme.gradient)
                            .clipShape(Circle())
                            .shadow(color: MacVoiceTheme.accent.opacity(0.45), radius: 24, y: 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(appModel.voice.phase == .transcribing)
                }

                VStack(spacing: 7) {
                    Text(heroTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(heroSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(MacVoiceTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                if case .failure(let message, let canRetry) = appModel.voice.phase {
                    VStack(spacing: 12) {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                        if canRetry {
                            HStack {
                                Button {
                                    appModel.voice.retryTranscription()
                                } label: {
                                    Label(L10n.text("action.retry"), systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(GradientButtonStyle())
                                Button {
                                    appModel.voice.discardFailedRecording()
                                } label: {
                                    Text(L10n.text("action.discard"))
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                } else if let notice = appModel.voice.notice {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                        Text(settings.hotKey.displayValue)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.07), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }

    private var lastTranscription: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(L10n.text("main.latest"), systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appModel.voice.lastTranscription, forType: .string)
                    } label: {
                        Label(L10n.text("action.copy"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MacVoiceTheme.cyan)
                }
                Text(appModel.voice.lastTranscription)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.88))
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if settings.historyEnabled {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L10n.text("main.history"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    if !history.isEmpty {
                        Button(L10n.text("action.clear")) {
                            history.forEach { modelContext.delete($0) }
                            try? modelContext.save()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MacVoiceTheme.secondaryText)
                    }
                }

                if history.isEmpty {
                    GlassCard {
                        VStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 28))
                                .foregroundStyle(MacVoiceTheme.secondaryText)
                            Text(L10n.text("history.empty"))
                                .foregroundStyle(MacVoiceTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(history.prefix(30)) { item in
                            HistoryRow(item: item) {
                                modelContext.delete(item)
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
        }
    }

    private var heroIcon: String {
        switch appModel.voice.phase {
        case .recording: "stop.fill"
        case .transcribing: "ellipsis"
        default: "mic.fill"
        }
    }

    private var heroTitle: String {
        switch appModel.voice.phase {
        case .idle: L10n.text("status.ready")
        case .recording: L10n.text("status.recording")
        case .transcribing: L10n.text("status.transcribing")
        case .success: L10n.text("status.copied")
        case .failure: L10n.text("status.failed")
        }
    }

    private var heroSubtitle: String {
        switch appModel.voice.phase {
        case .idle: L10n.text("status.ready_detail")
        case .recording: L10n.text("status.recording_detail")
        case .transcribing: L10n.text("status.transcribing_detail")
        case .success: L10n.text("status.copied_detail")
        case .failure(_, let canRetry):
            canRetry ? L10n.text("status.retry_detail") : L10n.text("status.failed_detail")
        }
    }
}

private struct HistoryRow: View {
    let item: TranscriptionRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "quote.bubble.fill")
                .foregroundStyle(MacVoiceTheme.accent)
                .frame(width: 28, height: 28)
                .background(MacVoiceTheme.accent.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 7) {
                Text(item.text)
                    .font(.system(size: 14))
                    .lineLimit(3)
                    .textSelection(.enabled)
                Text("\(item.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(Int(item.duration))s")
                    .font(.system(size: 11))
                    .foregroundStyle(MacVoiceTheme.secondaryText)
            }
            Spacer()
            Menu {
                Button(L10n.text("action.copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.text, forType: .string)
                }
                Button(L10n.text("action.delete"), role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(16)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}
