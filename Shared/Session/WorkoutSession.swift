import Foundation

/// The single source of live workout state on each device. Views read
/// `workout` / `lastSummary` and call the methods below; every local change
/// is forwarded to the other device, and remote changes arrive via `handle`.
@MainActor
final class WorkoutSession: ObservableObject {
    static let shared = WorkoutSession()

    @Published private(set) var workout: LiveWorkout?
    @Published private(set) var lastSummary: WorkoutSummary?

    var isActive: Bool { workout != nil }

    /// Input source recorded for shots logged with this device's buttons.
    var buttonSource: InputSource

    var send: (SessionEvent) -> Void = { _ in }
    /// Called once whenever a workout begins on this device, whichever side started it.
    var onStart: ((LiveWorkout) -> Void)?
    /// Called once whenever a workout finishes, however it was ended.
    var onFinish: ((LiveWorkout, Date) -> Void)?
    /// Called for shots logged on this device only (not ones from the peer).
    var onLocalShot: ((LiveShot) -> Void)?

    init(buttonSource: InputSource = WorkoutSession.defaultButtonSource) {
        self.buttonSource = buttonSource
    }

    nonisolated static var defaultButtonSource: InputSource {
        #if os(watchOS)
        .watchButton
        #else
        .iPhoneButton
        #endif
    }

    // MARK: - Local actions

    func start(type: WorkoutType, at date: Date = Date()) {
        guard workout == nil else { return }
        let new = LiveWorkout(workoutType: type, startDate: date)
        lastSummary = nil
        workout = new
        send(.start(new))
        onStart?(new)
    }

    func logMake() { logShot(.made) }
    func logMiss() { logShot(.missed) }

    func logShot(_ result: ShotResult, source: InputSource? = nil, at date: Date = Date()) {
        guard var current = workout else { return }
        let shot = LiveShot(result: result, inputSource: source ?? buttonSource, date: date)
        current.add(shot)
        workout = current
        send(.shot(workoutID: current.id, shot: shot))
        onLocalShot?(shot)
    }

    /// Removes the most recent shot, whichever device logged it.
    func undo() {
        guard var current = workout, let last = current.lastShot else { return }
        current.removeShot(id: last.id)
        workout = current
        send(.undo(workoutID: current.id, shotID: last.id))
    }

    func end(at date: Date = Date()) {
        guard let current = workout else { return }
        finish(current, endDate: date)
        send(.end(workoutID: current.id, endDate: date))
    }

    func dismissSummary() {
        lastSummary = nil
    }

    /// Call at launch: picks up a workout the other device already has running.
    func requestSync() {
        guard workout == nil else { return }
        send(.requestSync)
    }

    // MARK: - Remote events

    func handle(_ event: SessionEvent) {
        switch event {
        case .start(let incoming):
            if let current = workout {
                guard current.id != incoming.id else { return }
                // Two different workouts: both devices settle on the earlier one.
                guard incoming.startDate < current.startDate else {
                    send(.start(current))
                    return
                }
                finish(current, endDate: incoming.startDate)
            }
            lastSummary = nil
            workout = incoming
            onStart?(incoming)

        case .shot(let workoutID, let shot):
            guard var current = workout, current.id == workoutID else { return }
            if current.add(shot) { workout = current }

        case .undo(let workoutID, let shotID):
            guard var current = workout, current.id == workoutID else { return }
            if current.removeShot(id: shotID) { workout = current }

        case .end(let workoutID, let endDate):
            guard let current = workout, current.id == workoutID else { return }
            finish(current, endDate: endDate)

        case .requestSync:
            if let current = workout { send(.start(current)) }
        }
    }

    private func finish(_ finished: LiveWorkout, endDate: Date) {
        workout = nil
        lastSummary = WorkoutSummary(workout: finished, endDate: endDate)
        onFinish?(finished, endDate)
    }
}
