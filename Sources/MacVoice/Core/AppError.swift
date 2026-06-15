import Foundation

enum AppError: LocalizedError, Equatable {
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case missingAPIKey
    case invalidAPIKey
    case recordingFailed(String)
    case recordingTooLarge
    case emptyRecording
    case networkUnavailable
    case requestTimedOut
    case rateLimited
    case serverError(Int, String)
    case invalidResponse
    case transcriptionFailed(String)
    case pasteFailed
    case hotKeyConflict

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            L10n.text("error.microphone")
        case .accessibilityPermissionDenied:
            L10n.text("error.accessibility")
        case .missingAPIKey:
            L10n.text("error.missing_key")
        case .invalidAPIKey:
            L10n.text("error.invalid_key")
        case .recordingFailed(let details):
            L10n.format("error.recording", details)
        case .recordingTooLarge:
            L10n.text("error.recording_too_large")
        case .emptyRecording:
            L10n.text("error.empty_recording")
        case .networkUnavailable:
            L10n.text("error.network")
        case .requestTimedOut:
            L10n.text("error.timeout")
        case .rateLimited:
            L10n.text("error.rate_limit")
        case .serverError(_, let message):
            message
        case .invalidResponse:
            L10n.text("error.invalid_response")
        case .transcriptionFailed(let message):
            message
        case .pasteFailed:
            L10n.text("error.paste")
        case .hotKeyConflict:
            L10n.text("error.hotkey")
        }
    }
}
