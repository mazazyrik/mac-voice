import Foundation
import SwiftData

@Model
final class TranscriptionRecord {
    var id: UUID
    var text: String
    var createdAt: Date
    var duration: TimeInterval
    var wasAutoPasted: Bool

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        duration: TimeInterval,
        wasAutoPasted: Bool
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.duration = duration
        self.wasAutoPasted = wasAutoPasted
    }
}
