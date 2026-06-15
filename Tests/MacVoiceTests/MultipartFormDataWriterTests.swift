import Foundation
import XCTest
@testable import MacVoice

final class MultipartFormDataWriterTests: XCTestCase {
    func testWritesFieldsAndFileToDisk() throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try Data(repeating: 0xAB, count: 1_024).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var writer = MultipartFormDataWriter(boundary: "Boundary")
        writer.addField(name: "model", value: "gpt-4o-transcribe")
        writer.addField(name: "language", value: "ru")
        writer.addFile(
            name: "file",
            filename: "sample.wav",
            mimeType: "audio/wav",
            fileURL: audioURL
        )
        try writer.write(to: outputURL)

        let text = try String(contentsOf: outputURL, encoding: .isoLatin1)
        XCTAssertTrue(text.contains("name=\"model\""))
        XCTAssertTrue(text.contains("gpt-4o-transcribe"))
        XCTAssertTrue(text.contains("filename=\"sample.wav\""))
        XCTAssertTrue(text.contains(String(repeating: "\u{AB}", count: 1_024)))
        XCTAssertTrue(text.hasSuffix("--Boundary--\r\n"))
    }
}
