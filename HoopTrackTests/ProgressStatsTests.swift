import XCTest
@testable import HoopTrack

final class ProgressStatsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    /// Wednesday 14 Oct 2026, midday UTC.
    private var now: Date { date(day: 14, hour: 12) }

    private func date(day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func workout(
        day: Int, hour: Int = 10, makes: Int, attempts: Int, streak: Int = 0, type: WorkoutType = .freeShoot
    ) -> Workout {
        Workout(
            date: date(day: day, hour: hour),
            duration: 600,
            workoutType: type,
            totalMakes: makes,
            totalAttempts: attempts,
            shootingPct: attempts == 0 ? 0 : Double(makes) / Double(attempts),
            bestStreak: streak
        )
    }

    private func stats(_ workouts: [Workout], type: WorkoutType? = nil) -> ProgressStats {
        ProgressStats(workouts: workouts, type: type, calendar: calendar, now: now)
    }

    func testEmptyHistory() {
        let stats = stats([])
        XCTAssertTrue(stats.trend.isEmpty)
        XCTAssertEqual(stats.allTime, PeriodTotals())
        XCTAssertEqual(stats.today.shootingPct, 0)
        XCTAssertNil(stats.latestVsPrevious)
        XCTAssertNil(stats.weekOverWeekChange)
        XCTAssertNil(stats.bestShootingPct)
        XCTAssertNil(stats.longestStreak)
        XCTAssertNil(stats.mostMakes)
    }

    func testTrendIsOldestFirstWhateverTheInputOrder() {
        let stats = stats([
            workout(day: 13, makes: 6, attempts: 10),
            workout(day: 2, makes: 4, attempts: 10),
            workout(day: 9, makes: 5, attempts: 10),
        ])
        XCTAssertEqual(stats.trend.map(\.shootingPct), [0.4, 0.5, 0.6])
    }

    func testTodayAndWeekTotalsAreWeightedByShots() {
        let stats = stats([
            workout(day: 14, hour: 8, makes: 40, attempts: 50),   // today
            workout(day: 14, hour: 9, makes: 1, attempts: 10),    // today
            workout(day: 12, makes: 9, attempts: 20),             // Monday this week
            workout(day: 11, makes: 10, attempts: 40),            // Sunday: last week
            workout(day: 5, makes: 10, attempts: 40),             // Monday last week
            workout(day: 4, makes: 30, attempts: 30),             // two weeks ago
        ])

        XCTAssertEqual(stats.today.workouts, 2)
        XCTAssertEqual(stats.today.makes, 41)
        XCTAssertEqual(stats.today.attempts, 60)
        XCTAssertEqual(stats.today.shootingPct, 41.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(stats.today.duration, 1200)

        XCTAssertEqual(stats.thisWeek.attempts, 80)
        XCTAssertEqual(stats.thisWeek.makes, 50)
        XCTAssertEqual(stats.lastWeek.attempts, 80)
        XCTAssertEqual(stats.lastWeek.makes, 20)
        XCTAssertEqual(try XCTUnwrap(stats.weekOverWeekChange), 0.625 - 0.25, accuracy: 0.0001)
        XCTAssertEqual(stats.allTime.workouts, 6)
    }

    func testWeekOverWeekNeedsShotsInBothWeeks() {
        XCTAssertNil(stats([workout(day: 13, makes: 5, attempts: 10)]).weekOverWeekChange)
    }

    func testLatestVersusPreviousSession() throws {
        let comparison = try XCTUnwrap(stats([
            workout(day: 13, makes: 7, attempts: 10),
            workout(day: 9, makes: 5, attempts: 10),
            workout(day: 2, makes: 9, attempts: 10),
        ]).latestVsPrevious)

        XCTAssertEqual(comparison.latestPct, 0.7)
        XCTAssertEqual(comparison.previousPct, 0.5)
        XCTAssertEqual(comparison.change, 0.2, accuracy: 0.0001)
        XCTAssertNil(stats([workout(day: 13, makes: 7, attempts: 10)]).latestVsPrevious)
    }

    func testPersonalBests() throws {
        let tiny = workout(day: 1, makes: 3, attempts: 3, streak: 3)          // 100% but too few shots
        let accurate = workout(day: 5, makes: 18, attempts: 20, streak: 9)
        let volume = workout(day: 9, makes: 60, attempts: 100, streak: 12)
        let laterTie = workout(day: 12, makes: 18, attempts: 20, streak: 12)
        let stats = stats([volume, tiny, laterTie, accurate])

        let bestPct = try XCTUnwrap(stats.bestShootingPct)
        XCTAssertEqual(bestPct.value, 0.9)
        XCTAssertEqual(bestPct.workoutID, accurate.id, "a tie keeps the earlier record")
        XCTAssertEqual(stats.longestStreak?.value, 12)
        XCTAssertEqual(stats.longestStreak?.workoutID, volume.id)
        XCTAssertEqual(stats.mostMakes?.value, 60)
        XCTAssertEqual(stats.mostMakes?.workoutID, volume.id)
    }

    func testFilteringByWorkoutType() {
        let all = [
            workout(day: 13, makes: 8, attempts: 10, type: .freeThrow),
            workout(day: 12, makes: 2, attempts: 10, type: .threePointer),
            workout(day: 9, makes: 6, attempts: 10, type: .freeThrow),
        ]
        let freeThrows = stats(all, type: .freeThrow)

        XCTAssertEqual(freeThrows.trend.map(\.shootingPct), [0.6, 0.8])
        XCTAssertEqual(freeThrows.allTime.attempts, 20)
        XCTAssertEqual(freeThrows.latestVsPrevious?.previousPct, 0.6)
        XCTAssertTrue(stats(all, type: .midrange).trend.isEmpty)
    }

    func testOrderedShotsAndFormatting() {
        let saved = workout(day: 13, makes: 1, attempts: 2)
        saved.shots = [
            ShotEvent(shotNumber: 2, result: .missed, inputSource: .watchButton),
            ShotEvent(shotNumber: 1, result: .made, inputSource: .watchButton),
        ]
        XCTAssertEqual(saved.orderedShots.map(\.shotNumber), [1, 2])
        XCTAssertEqual(saved.totalMisses, 1)

        XCTAssertEqual(StatFormat.signedPoints(0.05), "+5 pts")
        XCTAssertEqual(StatFormat.signedPoints(-0.031), "-3 pts")
        XCTAssertEqual(StatFormat.signedPoints(0), "0 pts")
    }
}
