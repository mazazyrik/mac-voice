import AppKit
import Combine
import Foundation
import SwiftData

enum VoiceSessionPhase: Equatable {
    case idle
    case recording(startedAt: Date)
    case transcribing
    case success(String)
    case failure(message: String, canRetry: Bool)

    var isActive: Bool {
        switch self {
        case .recording, .transcribing:
            true
        default:
            false
        }
    }
}

@MainActor
final class VoiceSessionController: ObservableObject {
    @Published private(set) var phase: VoiceSessionPhase = .idle
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var lastTranscription = ""
    @Published private(set) var notice: String?

    var hasPendingRecording: Bool { pendingAudio != nil }

    private let recorder: AudioRecording
    private let transcriptionClient: TranscriptionProviding
    private let keychain: APIKeyStoring
    private let settings: AppSettings
    private let clipboard: ClipboardService
    private let sounds: SoundFeedbackService
    private let modelContext: ModelContext

    private var pendingAudio: RecordedAudio?
    private var targetApplication: NSRunningApplication?
    private var transcribingTask: Task<Void, Never>?
    private var lastLevelUpdate: Date?

    init(
        recorder: AudioRecording,
        transcriptionClient: TranscriptionProviding,
        keychain: APIKeyStoring,
        settings: AppSettings,
        clipboard: ClipboardService,
        sounds: SoundFeedbackService,
        modelContext: ModelContext
    ) {
        self.recorder = recorder
        self.transcriptionClient = transcriptionClient
        self.keychain = keychain
        self.settings = settings
        self.clipboard = clipboard
        self.sounds = sounds
        self.modelContext = modelContext
        recorder.onLevel = { [weak self] level in
            guard let self else { return }
            guard case .recording = phase else { return }
            let now = Date()
            if let lastLevelUpdate, now.timeIntervalSince(lastLevelUpdate) < 0.1 {
                return
            }
            lastLevelUpdate = now
            audioLevel = level
        }
    }

    func toggleRecording() {
        switch phase {
        case .recording:
            stopRecording()
        case .transcribing:
            break
        default:
            Task { await startRecording() }
        }
    }

    func startRecording() async {
        guard !phase.isActive else { return }
        discardPendingRecording()
        guard await recorder.requestPermission() else {
            fail(AppError.microphonePermissionDenied, canRetry: false)
            return
        }
        do {
            targetApplication = NSWorkspace.shared.frontmostApplication
            notice = nil
            try recorder.start()
            phase = .recording(startedAt: Date())
            sounds.play(.start, enabled: settings.soundEnabled)
        } catch {
            fail(error, canRetry: false)
        }
    }

    func stopRecording() {
        guard case .recording = phase else { return }
        do {
            pendingAudio = try recorder.stop()
            sounds.play(.stop, enabled: settings.soundEnabled)
            transcribePendingRecording()
        } catch {
            fail(error, canRetry: false)
        }
    }

    func retryTranscription() {
        guard pendingAudio != nil else {
            fail(AppError.emptyRecording, canRetry: false)
            return
        }
        transcribePendingRecording()
    }

    func cancelAndReset() {
        transcribingTask?.cancel()
        transcribingTask = nil
        recorder.cancel()
        discardPendingRecording()
        audioLevel = 0
        lastLevelUpdate = nil
        phase = .idle
    }

    func discardFailedRecording() {
        guard case .failure = phase else { return }
        discardPendingRecording()
        notice = nil
        phase = .idle
    }

    func resetPresentation() {
        guard !phase.isActive else { return }
        phase = .idle
    }

    func discardPendingRecording() {
        if let pendingAudio {
            try? FileManager.default.removeItem(at: pendingAudio.url)
        }
        pendingAudio = nil
    }

    private func transcribePendingRecording() {
        guard let pendingAudio else { return }
        transcribingTask?.cancel()
        phase = .transcribing
        transcribingTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let apiKey = try keychain.readAPIKey(), !apiKey.isEmpty else {
                    throw AppError.missingAPIKey
                }
                let result = try await transcriptionClient.transcribe(
                    audioURL: pendingAudio.url,
                    apiKey: apiKey,
                    vocabulary: settings.customVocabulary
                )
                guard !Task.isCancelled else { return }
                await finish(result.text, audio: pendingAudio)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let retryable = (error as? AppError) != .recordingTooLarge
                    && (error as? AppError) != .emptyRecording
                fail(error, canRetry: retryable)
            }
        }
    }

    private func finish(_ text: String, audio: RecordedAudio) async {
        clipboard.copy(text)
        var pasted = false
        notice = nil
        if settings.autoPaste {
            do {
                try await clipboard.paste(into: targetApplication)
                pasted = true
            } catch {
                notice = AppError.pasteFailed.localizedDescription
            }
        }
        lastTranscription = text
        if settings.historyEnabled {
            modelContext.insert(
                TranscriptionRecord(
                    text: text,
                    duration: audio.duration,
                    wasAutoPasted: pasted
                )
            )
            try? modelContext.save()
        }
        discardPendingRecording()
        phase = .success(text)
        sounds.play(.success, enabled: settings.soundEnabled)
    }

    private func fail(_ error: Error, canRetry: Bool) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        notice = nil
        phase = .failure(message: message, canRetry: canRetry && pendingAudio != nil)
        sounds.play(.error, enabled: settings.soundEnabled)
    }
}
