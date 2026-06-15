import Foundation
import XCTest
@testable import MacVoice

final class PerformanceTests: XCTestCase {
    func testMultipartWriterPerformance() throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try Data(repeating: 0x01, count: 512 * 1_024).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        measure {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: outputURL) }

            var writer = MultipartFormDataWriter(boundary: "PerfBoundary")
            writer.addField(name: "model", value: "gpt-4o-transcribe")
            writer.addField(name: "language", value: "ru")
            writer.addField(name: "response_format", value: "json")
            writer.addField(name: "prompt", value: "test prompt")
            writer.addFile(
                name: "file",
                filename: "sample.wav",
                mimeType: "audio/wav",
                fileURL: audioURL
            )
            try? writer.write(to: outputURL)
        }
    }
}
