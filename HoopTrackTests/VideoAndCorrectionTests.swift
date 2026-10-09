import XCTest
import SwiftData
@testable import HoopTrack

@MainActor
final class VideoAndCorrectionTests: XCTestCase {
    /// Held for the whole test: a context is unusable once its container is released.
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Workout.self, ShotEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        self.container = container
        return container.mainContext
    }

    /// Saved workout with the given results, one shot every 10 s from t=10.
    private func savedWorkout(_ results: [ShotResult], video: RecordedVideo? = nil, in context: ModelContext) throws -> Workout {
        let start = Date(timeIntervalSince1970: 1_000)
        var live = LiveWorkout(workoutType: .freeShoot, startDate: start)
        for (index, result) in results.enumerated() {
            live.add(LiveShot(result: result, inputSource: .watchButton, date: start.addingTimeInterval(Double(index + 1) * 10)))
        }
        return try XCTUnwrap(WorkoutRecorder.save(live, endDate: start.addingTimeInterval(600), video: video, shotOffset: 4, in: context))
    }

    func testTimestampBacksUpByTheOffsetAndNeverGoesNegative() {
        let start = Date(timeIntervalSince1970: 500)
        XCTAssertEqual(VideoTimestamp.seconds(shotDate: start.addingTimeInterval(30), videoStart: start, offset: 4), 26)
        XCTAssertEqual(VideoTimestamp.seconds(shotDate: start.addingTimeInterval(2), videoStart: start, offset: 4), 0)
        XCTAssertEqual(VideoTimestamp.seconds(shotDate: start.addingTimeInterval(-5), videoStart: start, offset: 4), 0)
    }

    func testShotsGetVideoTimestampsOnlyWhenRecorded() throws {
        let context = try makeContext()
        let plain = try savedWorkout([.made, .missed], in: context)
        XCTAssertNil(plain.videoFileURL)
        XCTAssertEqual(plain.orderedShots.map(\.videoTimestamp), [nil, nil])

        // Camera started 3 s into the workout.
        let video = RecordedVideo(url: VideoStore.newURL(for: UUID()), startDate: Date(timeIntervalSince1970: 1_003))
        let recorded = try savedWorkout([.made, .missed, .made], video: video, in: context)
        XCTAssertEqual(recorded.videoFileURL, video.url)
        XCTAssertEqual(recorded.orderedShots.map(\.videoTimestamp), [3, 13, 23])
        XCTAssertNil(recorded.videoURL, "no file was written, so there is nothing to play")
    }

    func testVideoURLFindsTheFileByNameAndEmptyWorkoutDiscardsIt() throws {
        let context = try makeContext()
        let url = VideoStore.newURL(for: UUID())
        try Data("video".utf8).write(to: url)
        defer { VideoStore.discard(url) }

        let workout = try savedWorkout([.made], video: RecordedVideo(url: url, startDate: Date(timeIntervalSince1970: 1_000)), in: context)
        // Simulate the app folder moving between installs: only the name is trusted.
        workout.videoFileURL = URL(fileURLWithPath: "/old/container/Documents/Videos/\(url.lastPathComponent)")
        XCTAssertEqual(workout.videoURL?.lastPathComponent, url.lastPathComponent)

        let emptyURL = VideoStore.newURL(for: UUID())
        try Data("video".utf8).write(to: emptyURL)
        let empty = WorkoutRecorder.save(
            LiveWorkout(workoutType: .freeShoot), endDate: Date(),
            video: RecordedVideo(url: emptyURL, startDate: Date()), in: context
        )
        XCTAssertNil(empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyURL.path))
    }

    func testCorrectingAShotUpdatesStatsAndRemembersTheOriginal() throws {
        let context = try makeContext()
        let workout = try savedWorkout([.made, .missed, .made, .made], in: context)
        let second = workout.orderedShots[1]

        workout.setResult(.made, for: second)
        XCTAssertTrue(second.corrected)
        XCTAssertEqual(second.originalResult, .missed)
        XCTAssertEqual(workout.totalMakes, 4)
        XCTAssertEqual(workout.totalAttempts, 4)
        XCTAssertEqual(workout.shootingPct, 1)
        XCTAssertEqual(workout.bestStreak, 4)

        workout.setResult(.made, for: second) // no change
        XCTAssertEqual(second.originalResult, .missed)

        workout.setResult(.missed, for: second) // back to how it was logged
        XCTAssertFalse(second.corrected)
        XCTAssertNil(second.originalResult)
        XCTAssertEqual(workout.totalMakes, 3)
        XCTAssertEqual(workout.bestStreak, 2)
    }

    func testNotAShotLeavesTheListButNotTheStatsAndCanBeRestored() throws {
        let context = try makeContext()
        let workout = try savedWorkout([.made, .missed, .made], in: context)
        let miss = workout.orderedShots[1]

        workout.setExcluded(true, for: miss)
        XCTAssertEqual(workout.shots.count, 3)
        XCTAssertEqual(workout.totalAttempts, 2)
        XCTAssertEqual(workout.totalMakes, 2)
        XCTAssertEqual(workout.shootingPct, 1)
        XCTAssertEqual(workout.bestStreak, 2, "the makes either side now run together")
        XCTAssertEqual(miss.result, .missed)

        workout.setExcluded(false, for: miss)
        XCTAssertEqual(workout.totalAttempts, 3)
        XCTAssertEqual(workout.shootingPct, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(workout.bestStreak, 1)

        for shot in workout.shots { workout.setExcluded(true, for: shot) }
        XCTAssertEqual(workout.totalAttempts, 0)
        XCTAssertEqual(workout.shootingPct, 0)
    }

    func testSessionReportsStartOnWhicheverDeviceBegins() {
        let watch = WorkoutSession(buttonSource: .watchButton)
        let phone = WorkoutSession(buttonSource: .iPhoneButton)
        watch.send = { phone.handle($0) }
        phone.send = { watch.handle($0) }
        var phoneStarts: [UUID] = []
        phone.onStart = { phoneStarts.append($0.id) }

        watch.start(type: .freeShoot)
        let first = try? XCTUnwrap(watch.workout?.id)
        phone.handle(.start(watch.workout!)) // duplicate delivery
        watch.end()
        phone.start(type: .freeThrow)

        XCTAssertEqual(phoneStarts.count, 2)
        XCTAssertEqual(phoneStarts.first, first)
    }
}
