import XCTest
import SwiftData
@testable import HoopTrack

@MainActor
final class WorkoutSessionTests: XCTestCase {
    private func shot(_ result: ShotResult, at offset: TimeInterval) -> LiveShot {
        LiveShot(result: result, inputSource: .watchButton, date: Date(timeIntervalSince1970: offset))
    }

    /// Two sessions wired to each other, standing in for the Watch and iPhone.
    private func makePair() -> (watch: WorkoutSession, phone: WorkoutSession) {
        let watch = WorkoutSession(buttonSource: .watchButton)
        let phone = WorkoutSession(buttonSource: .iPhoneButton)
        watch.send = { phone.handle($0) }
        phone.send = { watch.handle($0) }
        return (watch, phone)
    }

    func testStatsAndStreaks() {
        var workout = LiveWorkout(workoutType: .freeShoot, startDate: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(workout.shootingPct, 0)

        let results: [ShotResult] = [.made, .made, .made, .missed, .made, .made]
        for (index, result) in results.enumerated() {
            workout.add(shot(result, at: Double(index + 1)))
        }

        XCTAssertEqual(workout.attempts, 6)
        XCTAssertEqual(workout.makes, 5)
        XCTAssertEqual(workout.misses, 1)
        XCTAssertEqual(workout.shootingPct, 5.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(workout.currentStreak, 2)
        XCTAssertEqual(workout.bestStreak, 3)
        XCTAssertEqual(workout.elapsed(at: Date(timeIntervalSince1970: 90)), 90)
    }

    func testShotsStayTimeOrderedAndDuplicatesAreIgnored() {
        var workout = LiveWorkout(workoutType: .freeShoot, startDate: Date(timeIntervalSince1970: 0))
        let late = shot(.missed, at: 20)
        let early = shot(.made, at: 10)

        XCTAssertTrue(workout.add(late))
        XCTAssertTrue(workout.add(early))
        XCTAssertFalse(workout.add(late))

        XCTAssertEqual(workout.shots.map(\.id), [early.id, late.id])
        XCTAssertEqual(workout.currentStreak, 0)
    }

    func testWatchShotsReachPhoneAndBothAgree() {
        let (watch, phone) = makePair()

        watch.start(type: .freeThrow)
        watch.logMake()
        watch.logMiss()
        phone.logMake()

        XCTAssertEqual(phone.workout?.workoutType, .freeThrow)
        XCTAssertEqual(phone.workout, watch.workout)
        XCTAssertEqual(phone.workout?.attempts, 3)
        XCTAssertEqual(phone.workout?.makes, 2)
        XCTAssertEqual(phone.workout?.shots.map(\.inputSource), [.watchButton, .watchButton, .iPhoneButton])
    }

    func testUndoRemovesLastShotOnBothDevices() {
        let (watch, phone) = makePair()

        watch.start(type: .freeShoot)
        watch.logMake()
        watch.logMiss()
        phone.undo()

        XCTAssertEqual(watch.workout?.attempts, 1)
        XCTAssertEqual(watch.workout?.makes, 1)
        XCTAssertEqual(phone.workout, watch.workout)

        watch.undo()
        watch.undo()
        XCTAssertEqual(phone.workout?.attempts, 0)
    }

    func testEndFromEitherDeviceFinishesBothExactlyOnce() {
        let (watch, phone) = makePair()
        var finishCount = 0
        phone.onFinish = { _, _ in finishCount += 1 }

        let start = Date(timeIntervalSince1970: 1_000)
        watch.start(type: .threePointer, at: start)
        watch.logMake(); watch.logMake(); watch.logMiss()
        watch.end(at: start.addingTimeInterval(300))

        XCTAssertNil(phone.workout)
        XCTAssertNil(watch.workout)
        XCTAssertEqual(finishCount, 1)
        XCTAssertEqual(phone.lastSummary, watch.lastSummary)
        XCTAssertEqual(phone.lastSummary?.duration, 300)
        XCTAssertEqual(phone.lastSummary?.makes, 2)
        XCTAssertEqual(phone.lastSummary?.attempts, 3)
        XCTAssertEqual(phone.lastSummary?.bestStreak, 2)

        // Late or repeated events for the finished workout change nothing.
        phone.logMake()
        phone.end()
        XCTAssertEqual(finishCount, 1)
    }

    func testLocalShotCallbackFiresOnlyForLocalShots() {
        let (watch, phone) = makePair()
        var watchLocalShots = 0
        watch.onLocalShot = { _ in watchLocalShots += 1 }

        watch.start(type: .freeShoot)
        watch.logMake()
        phone.logMake()

        XCTAssertEqual(watchLocalShots, 1)
    }

    func testRelaunchedDevicePicksUpTheRunningWorkout() {
        let (watch, phone) = makePair()
        watch.start(type: .midrange)
        watch.logMake()

        // The phone app restarts and comes back with no state.
        let relaunched = WorkoutSession(buttonSource: .iPhoneButton)
        watch.send = { relaunched.handle($0) }
        relaunched.send = { watch.handle($0) }
        relaunched.requestSync()

        XCTAssertEqual(relaunched.workout, watch.workout)
        XCTAssertEqual(relaunched.workout?.attempts, 1)
        _ = phone
    }

    func testConflictingWorkoutsSettleOnTheEarlierOne() {
        let (watch, phone) = makePair()
        var saved: [UUID] = []
        phone.onFinish = { workout, _ in saved.append(workout.id) }

        // Each starts while out of touch with the other.
        watch.send = { _ in }
        phone.send = { _ in }
        phone.start(type: .freeShoot, at: Date(timeIntervalSince1970: 100))
        watch.start(type: .freeThrow, at: Date(timeIntervalSince1970: 200))
        let earlier = phone.workout

        watch.send = { phone.handle($0) }
        phone.send = { watch.handle($0) }
        watch.logMake()          // ignored by the phone: unknown workout
        watch.requestSync()      // no-op: the watch thinks it is active
        phone.handle(.start(watch.workout!))

        XCTAssertEqual(phone.workout, earlier)
        XCTAssertEqual(watch.workout, earlier)
        XCTAssertTrue(saved.isEmpty)
    }

    func testEventsSurviveTheWirePayload() throws {
        var workout = LiveWorkout(workoutType: .midrange)
        let made = LiveShot(result: .made, inputSource: .watchGesture)
        workout.add(made)
        let events: [SessionEvent] = [
            .start(workout),
            .shot(workoutID: workout.id, shot: made),
            .undo(workoutID: workout.id, shotID: made.id),
            .end(workoutID: workout.id, endDate: Date()),
            .requestSync,
        ]

        for event in events {
            let payload = try XCTUnwrap(event.payload)
            XCTAssertEqual(SessionEvent(payload: payload), event)
        }
        XCTAssertNil(SessionEvent(payload: ["event": "garbage"]))
    }

    func testFinishedWorkoutIsSavedToHistory() throws {
        let container = try ModelContainer(
            for: Workout.self, ShotEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 5_000)
        var live = LiveWorkout(workoutType: .fiveSpot, startDate: start)
        live.add(LiveShot(result: .made, inputSource: .watchButton, date: start.addingTimeInterval(1)))
        live.add(LiveShot(result: .missed, inputSource: .iPhoneButton, date: start.addingTimeInterval(2)))

        WorkoutRecorder.save(live, endDate: start.addingTimeInterval(120), in: context)
        WorkoutRecorder.save(LiveWorkout(workoutType: .freeShoot), endDate: Date(), in: context)

        let saved = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(saved.count, 1, "the empty workout should not be saved")
        let workout = try XCTUnwrap(saved.first)
        XCTAssertEqual(workout.workoutType, .fiveSpot)
        XCTAssertEqual(workout.duration, 120)
        XCTAssertEqual(workout.totalMakes, 1)
        XCTAssertEqual(workout.totalAttempts, 2)
        XCTAssertEqual(workout.shootingPct, 0.5)
        XCTAssertEqual(workout.bestStreak, 1)
        let shots = workout.shots.sorted { $0.shotNumber < $1.shotNumber }
        XCTAssertEqual(shots.map(\.shotNumber), [1, 2])
        XCTAssertEqual(shots.map(\.result), [.made, .missed])
        XCTAssertEqual(shots.map(\.inputSource), [.watchButton, .iPhoneButton])
    }
}
