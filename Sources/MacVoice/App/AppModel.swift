import AppKit
import Combine
import Foundation
import SwiftData

@MainActor
final class AppModel: ObservableObject {
    let settings: AppSettings
    let voice: VoiceSessionController
    let keychain: APIKeyStoring
    let transcriptionClient: TranscriptionProviding
    let recorder: AudioRecording
    let clipboard: ClipboardService

    @Published private(set) var hotKeyError: String?
    @Published private(set) var apiKeyConfigured: Bool

    private let hotKeyService: GlobalHotKeyService
    private let sounds: SoundFeedbackService
    private var floatingPanel: FloatingPanelController?
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false

    init(modelContext: ModelContext) {
        let settings = AppSettings()
        let recorder = AudioRecorder()
        let keychain = CachedAPIKeyStore(backing: KeychainStore())
        let client = OpenAITranscriptionClient()
        let clipboard = ClipboardService()
        let sounds = SoundFeedbackService()
        var hasStoredKey = false
        do {
            hasStoredKey = try keychain.readAPIKey()?.isEmpty == false
        } catch {
            hasStoredKey = false
        }
        if UserDefaults.standard.bool(forKey: "uiTestingHasAPIKey") {
            hasStoredKey = true
        }

        self.settings = settings
        self.recorder = recorder
        self.keychain = keychain
        transcriptionClient = client
        self.clipboard = clipboard
        self.sounds = sounds
        apiKeyConfigured = hasStoredKey
        hotKeyService = GlobalHotKeyService()
        voice = VoiceSessionController(
            recorder: recorder,
            transcriptionClient: client,
            keychain: keychain,
            settings: settings,
            clipboard: clipboard,
            sounds: sounds,
            modelContext: modelContext
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        removeOrphanedTemporaryRecordings()
        floatingPanel = FloatingPanelController(controller: voice, settings: settings)
        hotKeyService.onPressed = { [weak self] in self?.handleGlobalHotKey() }
        registerHotKey(settings.hotKey)

        settings.$hotKey
            .dropFirst()
            .sink { [weak self] hotKey in self?.registerHotKey(hotKey) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.voice.cancelAndReset() }
            }
            .store(in: &cancellables)
    }

    func validateAndSaveAPIKey(_ apiKey: String) async throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.missingAPIKey }
        try await transcriptionClient.validate(apiKey: trimmed)
        try keychain.saveAPIKey(trimmed)
        apiKeyConfigured = true
    }

    func hasAPIKey() -> Bool {
        apiKeyConfigured
    }

    func removeAPIKey() throws {
        try keychain.deleteAPIKey()
        apiKeyConfigured = false
    }

    func requestMicrophonePermission() async -> Bool {
        await recorder.requestPermission()
    }

    func requestAccessibilityPermission() -> Bool {
        clipboard.isAccessibilityGranted(prompt: true)
    }

    func registerHotKey(_ hotKey: HotKey) {
        do {
            try hotKeyService.register(hotKey)
            hotKeyError = nil
        } catch {
            hotKeyError = error.localizedDescription
        }
    }

    private func handleGlobalHotKey() {
        voice.toggleRecording()
    }

    func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func removeOrphanedTemporaryRecordings() {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files where file.lastPathComponent.hasPrefix("MacVoice-") && file.pathExtension == "wav" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
