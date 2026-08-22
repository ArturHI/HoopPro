import Foundation
import SwiftData

@Model
final class ShotEvent {
    var id: UUID
    var shotNumber: Int
    var videoTimestamp: Double?
    var result: ShotResult
    var inputSource: InputSource
    var corrected: Bool
    var originalResult: ShotResult?
    var shotType: String?
    var aiConfidence: Double?

    init(
        id: UUID = UUID(),
        shotNumber: Int,
        videoTimestamp: Double? = nil,
        result: ShotResult,
        inputSource: InputSource,
        corrected: Bool = false,
        originalResult: ShotResult? = nil,
        shotType: String? = nil,
        aiConfidence: Double? = nil
    ) {
        self.id = id
        self.shotNumber = shotNumber
        self.videoTimestamp = videoTimestamp
        self.result = result
        self.inputSource = inputSource
        self.corrected = corrected
        self.originalResult = originalResult
        self.shotType = shotType
        self.aiConfidence = aiConfidence
    }
}
