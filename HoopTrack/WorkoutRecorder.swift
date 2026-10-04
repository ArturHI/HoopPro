import Foundation
import SwiftData

/// Turns a finished live workout into saved history.
@MainActor
enum WorkoutRecorder {
    /// Workouts with no shots are discarded rather than saved.
    @discardableResult
    static func save(_ live: LiveWorkout, endDate: Date, in context: ModelContext) -> Workout? {
        guard live.attempts > 0 else { return nil }

        let shots = live.shots.enumerated().map { index, shot in
            ShotEvent(
                id: shot.id,
                shotNumber: index + 1,
                result: shot.result,
                inputSource: shot.inputSource
            )
        }
        let workout = Workout(
            id: live.id,
            date: live.startDate,
            duration: live.elapsed(at: endDate),
            workoutType: live.workoutType,
            totalMakes: live.makes,
            totalAttempts: live.attempts,
            shootingPct: live.shootingPct,
            bestStreak: live.bestStreak,
            shots: shots
        )
        context.insert(workout)
        try? context.save()
        return workout
    }
}
