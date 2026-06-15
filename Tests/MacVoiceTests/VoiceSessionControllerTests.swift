import Foundation
import SwiftData
import XCTest
@testable import MacVoice

@MainActor
final class VoiceSessionControllerTests: XCTestCase {
    func testSameToggleStartsAndStopsRecordingThenCopiesResult() async throws {
        let suite = "MacVoiceToggleTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.autoPaste = false
        settings.soundEnabled = false
        settings.historyEnabled = false

        let container = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let recorder = MockAudioRecorder()
        let controller = VoiceSessionController(
            recorder: recorder,
            transcriptionClient: SequencedTranscriptionClient(
                results: [.success(TranscriptionResult(text: "Готовый текст."))]
            ),
            keychain: MockKeychain(key: "test-key"),
            settings: settings,
            clipboard: ClipboardService(),
            sounds: SoundFeedbackService(),
            modelContext: container.mainContext
        )

        controller.toggleRecording()
        try await waitUntil {
            if case .recording = controller.phase { return true }
            return false
        }

        controller.toggleRecording()
        try await waitUntil {
            controller.phase == .success("Готовый текст.")
        }

        XCTAssertEqual(recorder.startCount, 1)
        XCTAssertEqual(recorder.stopCount, 1)
        XCTAssertEqual(controller.lastTranscription, "Готовый текст.")
    }

    func testFailedTranscriptionCanRetrySameRecording() async throws {
        let suite = "MacVoiceVoiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.autoPaste = false
        settings.soundEnabled = false
        settings.historyEnabled = true

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TranscriptionRecord.self, configurations: configuration)
        let recorder = MockAudioRecorder()
        let client = SequencedTranscriptionClient(
            results: [
                .failure(AppError.networkUnavailable),
                .success(TranscriptionResult(text: "Повтор сработал."))
            ]
        )
        let controller = VoiceSessionController(
            recorder: recorder,
            transcriptionClient: client,
            keychain: MockKeychain(key: "test-key"),
            settings: settings,
            clipboard: ClipboardService(),
            sounds: SoundFeedbackService(),
            modelContext: container.mainContext
        )

        await controller.startRecording()
        XCTAssertEqual(recorder.startCount, 1)
        controller.stopRecording()

        try await waitUntil {
            if case .failure(_, let canRetry) = controller.phase { return canRetry }
            return false
        }
        XCTAssertTrue(controller.hasPendingRecording)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recorder.recordingURL.path))

        controller.retryTranscription()
        try await waitUntil {
            if case .success(let text) = controller.phase { return text == "Повтор сработал." }
            return false
        }

        XCTAssertFalse(controller.hasPendingRecording)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recorder.recordingURL.path))
        let callCount = await client.callCount
        XCTAssertEqual(callCount, 2)
        let descriptor = FetchDescriptor<TranscriptionRecord>()
        XCTAssertEqual(try container.mainContext.fetch(descriptor).count, 1)
    }

    func testCancelDeletesRecording() async throws {
        let settings = AppSettings(defaults: try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        settings.soundEnabled = false
        let container = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let recorder = MockAudioRecorder()
        let controller = VoiceSessionController(
            recorder: recorder,
            transcriptionClient: SequencedTranscriptionClient(results: []),
            keychain: MockKeychain(key: "key"),
            settings: settings,
            clipboard: ClipboardService(),
            sounds: SoundFeedbackService(),
            modelContext: container.mainContext
        )

        await controller.startRecording()
        controller.cancelAndReset()

        XCTAssertEqual(controller.phase, .idle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recorder.recordingURL.path))
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for state")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

@MainActor
private final class MockAudioRecorder: AudioRecording {
    var onLevel: ((Float) -> Void)?
    private(set) var isRecording = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    let recordingURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("wav")

    func requestPermission() async -> Bool { true }

    func start() throws {
        startCount += 1
        isRecording = true
        try Data(repeating: 0x01, count: 512).write(to: recordingURL)
    }

    func stop() throws -> RecordedAudio {
        stopCount += 1
        isRecording = false
        return RecordedAudio(url: recordingURL, duration: 1.25)
    }

    func cancel() {
        isRecording = false
        try? FileManager.default.removeItem(at: recordingURL)
    }
}

private actor SequencedTranscriptionClient: TranscriptionProviding {
    private var results: [Result<TranscriptionResult, AppError>]
    private(set) var callCount = 0

    init(results: [Result<TranscriptionResult, AppError>]) {
        self.results = results
    }

    func transcribe(audioURL: URL, apiKey: String, vocabulary: String) async throws -> TranscriptionResult {
        callCount += 1
        guard !results.isEmpty else { throw AppError.invalidResponse }
        return try results.removeFirst().get()
    }

    func validate(apiKey: String) async throws { }
}

private struct MockKeychain: APIKeyStoring {
    let key: String?
    func readAPIKey() throws -> String? { key }
    func saveAPIKey(_ key: String) throws { }
    func deleteAPIKey() throws { }
}
