import Foundation

struct TranscriptionResult: Codable, Equatable, Sendable {
    let text: String
}

protocol TranscriptionProviding: Sendable {
    func transcribe(audioURL: URL, apiKey: String, vocabulary: String) async throws -> TranscriptionResult
    func validate(apiKey: String) async throws
}

struct OpenAITranscriptionClient: TranscriptionProviding {
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func transcribe(audioURL: URL, apiKey: String, vocabulary: String) async throws -> TranscriptionResult {
        let fileSize = try audioURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize > 0 else { throw AppError.emptyRecording }
        guard fileSize < 25 * 1_024 * 1_024 else { throw AppError.recordingTooLarge }

        let boundary = "MacVoice-\(UUID().uuidString)"
        let multipartURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacVoice-upload-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: multipartURL) }

        var writer = MultipartFormDataWriter(boundary: boundary)
        writer.addField(name: "model", value: "gpt-4o-transcribe")
        writer.addField(name: "language", value: "ru")
        writer.addField(name: "response_format", value: "json")
        writer.addField(name: "prompt", value: prompt(vocabulary: vocabulary))
        writer.addFile(
            name: "file",
            filename: "macvoice-recording.wav",
            mimeType: "audio/wav",
            fileURL: audioURL
        )
        try writer.write(to: multipartURL)

        let transcriptionURL = baseURL
            .appendingPathComponent("audio")
            .appendingPathComponent("transcriptions")
        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await session.upload(for: request, fromFile: multipartURL)
            try Self.validate(response: response, data: data)
            let result = try JSONDecoder().decode(TranscriptionResult.self, from: data)
            let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw AppError.invalidResponse }
            return TranscriptionResult(text: trimmed)
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                throw AppError.networkUnavailable
            case .timedOut:
                throw AppError.requestTimedOut
            default:
                throw AppError.transcriptionFailed(error.localizedDescription)
            }
        } catch is DecodingError {
            throw AppError.invalidResponse
        } catch {
            throw AppError.transcriptionFailed(error.localizedDescription)
        }
    }

    func validate(apiKey: String) async throws {
        let modelURL = baseURL
            .appendingPathComponent("models")
            .appendingPathComponent("gpt-4o-transcribe")
        var request = URLRequest(url: modelURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        do {
            let (data, response) = try await session.data(for: request)
            try Self.validate(response: response, data: data)
        } catch let error as AppError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw AppError.requestTimedOut
        } catch {
            throw AppError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func prompt(vocabulary: String) -> String {
        let base = "Точная русская диктовка. Сохраняй слова и смысл дословно. Исправляй только регистр и пунктуацию."
        let words = vocabulary.trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? base : "\(base) Словарь имён и терминов: \(words)"
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AppError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let message = (try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data))?.error.message
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            switch http.statusCode {
            case 401:
                throw AppError.invalidAPIKey
            case 429:
                throw AppError.rateLimited
            default:
                throw AppError.serverError(http.statusCode, message)
            }
        }
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    struct APIError: Decodable { let message: String }
    let error: APIError
}

struct MultipartFormData {
    let boundary: String
    private var data = Data()

    init(boundary: String) {
        self.boundary = boundary
    }

    func addingField(name: String, value: String) -> Self {
        var copy = self
        copy.data.appendUTF8("--\(boundary)\r\n")
        copy.data.appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        copy.data.appendUTF8("\(value)\r\n")
        return copy
    }

    func addingFile(name: String, filename: String, mimeType: String, data fileData: Data) -> Self {
        var copy = self
        copy.data.appendUTF8("--\(boundary)\r\n")
        copy.data.appendUTF8(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        )
        copy.data.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        copy.data.append(fileData)
        copy.data.appendUTF8("\r\n")
        return copy
    }

    func finalized() -> Data {
        var copy = data
        copy.appendUTF8("--\(boundary)--\r\n")
        return copy
    }
}

struct MultipartFormDataWriter {
    let boundary: String
    private var fields: [(name: String, value: String)] = []
    private var file: (name: String, filename: String, mimeType: String, url: URL)?

    init(boundary: String) {
        self.boundary = boundary
    }

    mutating func addField(name: String, value: String) {
        fields.append((name, value))
    }

    mutating func addFile(name: String, filename: String, mimeType: String, fileURL: URL) {
        file = (name, filename, mimeType, fileURL)
    }

    func write(to destination: URL) throws {
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        for field in fields {
            try handle.writeUTF8("--\(boundary)\r\n")
            try handle.writeUTF8("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            try handle.writeUTF8("\(field.value)\r\n")
        }

        if let file {
            try handle.writeUTF8("--\(boundary)\r\n")
            try handle.writeUTF8(
                "Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n"
            )
            try handle.writeUTF8("Content-Type: \(file.mimeType)\r\n\r\n")
            let source = try FileHandle(forReadingFrom: file.url)
            defer { try? source.close() }
            while true {
                let chunk = try source.read(upToCount: 64 * 1_024)
                guard let chunk, !chunk.isEmpty else { break }
                try handle.write(contentsOf: chunk)
            }
            try handle.writeUTF8("\r\n")
        }

        try handle.writeUTF8("--\(boundary)--\r\n")
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension FileHandle {
    func writeUTF8(_ string: String) throws {
        guard let data = string.data(using: .utf8) else { return }
        try write(contentsOf: data)
    }
}
