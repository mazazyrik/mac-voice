import Foundation
import XCTest
@testable import MacVoice

final class OpenAITranscriptionClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testTranscriptionRequestAndResponse() async throws {
        let session = makeSession()
        let audioURL = try temporaryAudio()
        defer { try? FileManager.default.removeItem(at: audioURL) }

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            let body = try XCTUnwrap(MockURLProtocol.requestBody(from: request))
            let bodyText = try XCTUnwrap(String(data: body, encoding: .isoLatin1))
            XCTAssertTrue(bodyText.contains("gpt-4o-transcribe"))
            XCTAssertTrue(bodyText.contains("name=\"language\""))
            XCTAssertTrue(bodyText.contains("Codex, MacVoice"))
            return (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(#"{"text":"Привет, мир."}"#.utf8)
            )
        }

        let client = OpenAITranscriptionClient(
            session: session,
            baseURL: URL(string: "https://example.test/v1")!
        )
        let result = try await client.transcribe(
            audioURL: audioURL,
            apiKey: "test-key",
            vocabulary: "Codex, MacVoice"
        )
        XCTAssertEqual(result.text, "Привет, мир.")
    }

    func testUnauthorizedMapsToInvalidKey() async throws {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data(#"{"error":{"message":"Invalid key"}}"#.utf8)
            )
        }
        let client = OpenAITranscriptionClient(
            session: makeSession(),
            baseURL: URL(string: "https://example.test/v1")!
        )

        do {
            try await client.validate(apiKey: "bad-key")
            XCTFail("Expected invalid API key")
        } catch let error as AppError {
            XCTAssertEqual(error, .invalidAPIKey)
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func temporaryAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try Data(repeating: 0x01, count: 512).write(to: url)
        return url
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }

    static func requestBody(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            throw URLError(.badServerResponse)
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 16 * 1_024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
