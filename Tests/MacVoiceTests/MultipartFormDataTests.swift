import Foundation
import XCTest
@testable import MacVoice

final class MultipartFormDataTests: XCTestCase {
    func testBuildsFieldsAndFile() throws {
        let body = MultipartFormData(boundary: "Boundary")
            .addingField(name: "model", value: "gpt-4o-transcribe")
            .addingField(name: "language", value: "ru")
            .addingFile(
                name: "file",
                filename: "sample.wav",
                mimeType: "audio/wav",
                data: Data([0x01, 0x02])
            )
            .finalized()

        let text = try XCTUnwrap(String(data: body, encoding: .isoLatin1))
        XCTAssertTrue(text.contains("name=\"model\""))
        XCTAssertTrue(text.contains("gpt-4o-transcribe"))
        XCTAssertTrue(text.contains("name=\"language\""))
        XCTAssertTrue(text.contains("filename=\"sample.wav\""))
        XCTAssertTrue(text.hasSuffix("--Boundary--\r\n"))
    }
}
