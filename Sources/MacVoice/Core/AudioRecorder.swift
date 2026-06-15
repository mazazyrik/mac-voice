@preconcurrency import AVFoundation
import Foundation

struct RecordedAudio: Sendable, Equatable {
    let url: URL
    let duration: TimeInterval
}

@MainActor
protocol AudioRecording: AnyObject {
    var onLevel: ((Float) -> Void)? { get set }
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func start() throws
    func stop() throws -> RecordedAudio
    func cancel()
}

@MainActor
final class AudioRecorder: AudioRecording {
    var onLevel: ((Float) -> Void)?
    private(set) var isRecording = false

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var startedAt: Date?

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            true
        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: .audio)
        default:
            false
        }
    }

    func start() throws {
        guard !isRecording else { return }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw AppError.microphonePermissionDenied
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AppError.recordingFailed("No microphone input format")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacVoice-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        do {
            let file = try AVAudioFile(
                forWriting: url,
                settings: inputFormat.settings,
                commonFormat: inputFormat.commonFormat,
                interleaved: inputFormat.isInterleaved
            )
            audioFile = file
            outputURL = url
            startedAt = Date()
            let tapHandler = Self.makeTapHandler(file: file) { [weak self] level in
                self?.onLevel?(level)
            }
            input.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat, block: tapHandler)
            engine.prepare()
            try engine.start()
            isRecording = true
        } catch {
            cleanup()
            throw AppError.recordingFailed(error.localizedDescription)
        }
    }

    func stop() throws -> RecordedAudio {
        guard isRecording, let url = outputURL, let startedAt else {
            throw AppError.emptyRecording
        }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        audioFile = nil
        isRecording = false
        onLevel?(0)
        self.outputURL = nil
        self.startedAt = nil

        let duration = Date().timeIntervalSince(startedAt)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard duration > 0.15, size > 128 else {
            try? FileManager.default.removeItem(at: url)
            throw AppError.emptyRecording
        }
        return RecordedAudio(url: url, duration: duration)
    }

    func cancel() {
        if isRecording {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        cleanup()
        onLevel?(0)
    }

    private func cleanup() {
        audioFile = nil
        isRecording = false
        startedAt = nil
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        outputURL = nil
    }

    private nonisolated static func makeTapHandler(
        file: AVAudioFile,
        onLevel: @escaping @MainActor @Sendable (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            try? file.write(from: buffer)

            let level = normalizedLevel(buffer)
            Task { @MainActor in
                onLevel(level)
            }
        }
    }

    private nonisolated static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<frames {
            let sample = data[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frames))
        let decibels = 20 * log10(max(rms, 0.000_001))
        return min(max((decibels + 55) / 55, 0), 1)
    }
}
