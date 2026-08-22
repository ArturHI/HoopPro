import Foundation
import SwiftData

@Model
final class Workout {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var workoutType: WorkoutType
    var totalMakes: Int
    var totalAttempts: Int
    var shootingPct: Double
    var bestStreak: Int
    var videoFileURL: URL?
    @Relationship(deleteRule: .cascade) var shots: [ShotEvent]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval = 0,
        workoutType: WorkoutType,
        totalMakes: Int = 0,
        totalAttempts: Int = 0,
        shootingPct: Double = 0,
        bestStreak: Int = 0,
        videoFileURL: URL? = nil,
        shots: [ShotEvent] = []
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.workoutType = workoutType
        self.totalMakes = totalMakes
        self.totalAttempts = totalAttempts
        self.shootingPct = shootingPct
        self.bestStreak = bestStreak
        self.videoFileURL = videoFileURL
        self.shots = shots
    }
}
