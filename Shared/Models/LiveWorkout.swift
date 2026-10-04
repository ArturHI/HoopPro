import Foundation

struct LiveShot: Codable, Identifiable, Equatable {
    let id: UUID
    let result: ShotResult
    let inputSource: InputSource
    let date: Date

    init(id: UUID = UUID(), result: ShotResult, inputSource: InputSource, date: Date = Date()) {
        self.id = id
        self.result = result
        self.inputSource = inputSource
        self.date = date
    }
}

/// The in-progress workout, mirrored on both devices. Shots stay ordered by
/// time so both sides compute identical stats regardless of delivery order.
struct LiveWorkout: Codable, Identifiable, Equatable {
    let id: UUID
    let workoutType: WorkoutType
    let startDate: Date
    private(set) var shots: [LiveShot] = []

    init(id: UUID = UUID(), workoutType: WorkoutType, startDate: Date = Date()) {
        self.id = id
        self.workoutType = workoutType
        self.startDate = startDate
    }

    var attempts: Int { shots.count }
    var makes: Int { shots.filter { $0.result == .made }.count }
    var misses: Int { attempts - makes }

    /// Fraction from 0 to 1; 0 when no shots have been taken.
    var shootingPct: Double {
        attempts == 0 ? 0 : Double(makes) / Double(attempts)
    }

    var currentStreak: Int {
        shots.reversed().prefix { $0.result == .made }.count
    }

    var bestStreak: Int {
        var best = 0
        var run = 0
        for shot in shots {
            run = shot.result == .made ? run + 1 : 0
            best = max(best, run)
        }
        return best
    }

    var lastShot: LiveShot? { shots.last }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        max(0, date.timeIntervalSince(startDate))
    }

    /// Returns false if the shot was already present.
    @discardableResult
    mutating func add(_ shot: LiveShot) -> Bool {
        guard !shots.contains(where: { $0.id == shot.id }) else { return false }
        let index = shots.firstIndex { $0.date > shot.date } ?? shots.endIndex
        shots.insert(shot, at: index)
        return true
    }

    /// Returns false if no shot with that id exists.
    @discardableResult
    mutating func removeShot(id: UUID) -> Bool {
        guard let index = shots.firstIndex(where: { $0.id == id }) else { return false }
        shots.remove(at: index)
        return true
    }
}

struct WorkoutSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let workoutType: WorkoutType
    let date: Date
    let duration: TimeInterval
    let makes: Int
    let attempts: Int
    let shootingPct: Double
    let bestStreak: Int

    var misses: Int { attempts - makes }

    init(workout: LiveWorkout, endDate: Date) {
        id = workout.id
        workoutType = workout.workoutType
        date = workout.startDate
        duration = workout.elapsed(at: endDate)
        makes = workout.makes
        attempts = workout.attempts
        shootingPct = workout.shootingPct
        bestStreak = workout.bestStreak
    }
}
