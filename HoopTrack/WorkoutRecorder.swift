import Foundation
import SwiftData

/// Turns a finished live workout into saved history.
@MainActor
enum WorkoutRecorder {
    /// Workouts with no shots are discarded rather than saved, along with any video.
    @discardableResult
    static func save(
        _ live: LiveWorkout,
        endDate: Date,
        video: RecordedVideo? = nil,
        shotOffset: TimeInterval = VideoSettings.shotOffset,
        in context: ModelContext
    ) -> Workout? {
        guard live.attempts > 0 else {
            if let video { VideoStore.discard(video.url) }
            return nil
        }

        let shots = live.shots.enumerated().map { index, shot in
            ShotEvent(
                id: shot.id,
                shotNumber: index + 1,
                videoTimestamp: video.map {
                    VideoTimestamp.seconds(shotDate: shot.date, videoStart: $0.startDate, offset: shotOffset)
                },
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
            videoFileURL: video?.url,
            shots: shots
        )
        context.insert(workout)
        try? context.save()
        return workout
    }
}
