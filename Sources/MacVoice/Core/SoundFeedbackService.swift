@preconcurrency import AVFoundation
import Foundation

@MainActor
final class SoundFeedbackService {
    enum Cue {
        case start
        case stop
        case success
        case error
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var stopTask: Task<Void, Never>?

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ cue: Cue, enabled: Bool) {
        guard enabled else { return }
        stopTask?.cancel()
        if !engine.isRunning {
            try? engine.start()
        }
        let tones: [(frequency: Double, duration: Double)]
        switch cue {
        case .start:
            tones = [(520, 0.07), (680, 0.08)]
        case .stop:
            tones = [(620, 0.06), (450, 0.08)]
        case .success:
            tones = [(600, 0.06), (820, 0.09)]
        case .error:
            tones = [(260, 0.09), (210, 0.12)]
        }
        player.stop()
        for tone in tones {
            if let buffer = Self.buffer(frequency: tone.frequency, duration: tone.duration) {
                player.scheduleBuffer(buffer)
            }
        }
        player.play()
        let totalDuration = tones.reduce(0) { $0 + $1.duration }
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(totalDuration + 0.08))
            guard !Task.isCancelled else { return }
            self?.stopEngineIfIdle()
        }
    }

    private func stopEngineIfIdle() {
        guard !player.isPlaying else { return }
        engine.stop()
    }

    private nonisolated static func buffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
            let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            let progress = Double(frame) / Double(frameCount)
            let envelope = sin(.pi * progress)
            samples[frame] = Float(sin(2 * .pi * frequency * Double(frame) / sampleRate) * envelope * 0.12)
        }
        return buffer
    }
}
