import Foundation

/// Totals over a set of workouts. The percentage is weighted by shots, so a
/// 50-shot session counts for more than a 5-shot one.
struct PeriodTotals: Equatable {
    var workouts = 0
    var makes = 0
    var attempts = 0
    var duration: TimeInterval = 0

    var misses: Int { attempts - makes }
    /// Fraction from 0 to 1; 0 when there are no shots.
    var shootingPct: Double { attempts == 0 ? 0 : Double(makes) / Double(attempts) }

    init() {}

    init(_ workouts: [Workout]) {
        self.workouts = workouts.count
        makes = workouts.reduce(0) { $0 + $1.totalMakes }
        attempts = workouts.reduce(0) { $0 + $1.totalAttempts }
        duration = workouts.reduce(0) { $0 + $1.duration }
    }
}

/// One workout on the trend chart.
struct TrendPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let shootingPct: Double
    let attempts: Int
}

/// A personal best and the workout that set it.
struct PersonalBest<Value: Equatable>: Equatable {
    let value: Value
    let workoutID: UUID
    let date: Date
}

struct SessionComparison: Equatable {
    let latestPct: Double
    let previousPct: Double
    /// Latest minus previous, as a fraction (0.05 = five points better).
    var change: Double { latestPct - previousPct }
}

/// Everything the dashboard and progress screens show, computed from saved
/// workouts. Pass `type` to look at one workout type only.
struct ProgressStats {
    /// A workout needs at least this many shots to set the best-percentage record.
    static let minimumAttemptsForBestPct = 10

    /// Oldest first.
    let trend: [TrendPoint]
    let allTime: PeriodTotals
    let today: PeriodTotals
    let thisWeek: PeriodTotals
    let lastWeek: PeriodTotals
    /// Most recent workout against the one before it; nil with fewer than two.
    let latestVsPrevious: SessionComparison?

    let bestShootingPct: PersonalBest<Double>?
    let longestStreak: PersonalBest<Int>?
    let mostMakes: PersonalBest<Int>?

    /// This week's percentage minus last week's; nil unless both weeks have shots.
    var weekOverWeekChange: Double? {
        guard thisWeek.attempts > 0, lastWeek.attempts > 0 else { return nil }
        return thisWeek.shootingPct - lastWeek.shootingPct
    }

    init(workouts: [Workout], type: WorkoutType? = nil, calendar: Calendar = .current, now: Date = Date()) {
        let sorted = workouts
            .filter { type == nil || $0.workoutType == type }
            .sorted { $0.date < $1.date }

        trend = sorted.map {
            TrendPoint(id: $0.id, date: $0.date, shootingPct: $0.shootingPct, attempts: $0.totalAttempts)
        }
        allTime = PeriodTotals(sorted)
        today = PeriodTotals(sorted.filter { calendar.isDate($0.date, inSameDayAs: now) })

        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let previousWeek = week
            .flatMap { calendar.date(byAdding: .weekOfYear, value: -1, to: $0.start) }
            .flatMap { calendar.dateInterval(of: .weekOfYear, for: $0) }
        thisWeek = PeriodTotals(sorted.filter { week?.contains($0.date) ?? false })
        lastWeek = PeriodTotals(sorted.filter { previousWeek?.contains($0.date) ?? false })

        if sorted.count >= 2 {
            latestVsPrevious = SessionComparison(
                latestPct: sorted[sorted.count - 1].shootingPct,
                previousPct: sorted[sorted.count - 2].shootingPct
            )
        } else {
            latestVsPrevious = nil
        }

        // Ties go to the earliest workout: a record stands until it is beaten.
        func best<Value: Comparable>(_ candidates: [Workout], _ value: (Workout) -> Value) -> PersonalBest<Value>? {
            var winner: Workout?
            for workout in candidates where winner.map({ value(workout) > value($0) }) ?? true {
                winner = workout
            }
            return winner.map { PersonalBest(value: value($0), workoutID: $0.id, date: $0.date) }
        }
        bestShootingPct = best(sorted.filter { $0.totalAttempts >= Self.minimumAttemptsForBestPct }) { $0.shootingPct }
        longestStreak = best(sorted.filter { $0.bestStreak > 0 }) { $0.bestStreak }
        mostMakes = best(sorted.filter { $0.totalMakes > 0 }) { $0.totalMakes }
    }
}

extension Workout {
    var totalMisses: Int { totalAttempts - totalMakes }

    /// Shots in the order they were taken.
    var orderedShots: [ShotEvent] {
        shots.sorted { $0.shotNumber < $1.shotNumber }
    }
}
