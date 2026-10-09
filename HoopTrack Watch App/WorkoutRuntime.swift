import Foundation
import HealthKit

/// Keeps the Watch app running with the wrist down during a workout, so
/// gestures keep registering. It runs a HealthKit workout session for that
/// purpose only: nothing is read from Health and nothing is saved to it.
@MainActor
final class WorkoutRuntime: NSObject, ObservableObject {
    static let shared = WorkoutRuntime()

    enum State: Equatable {
        case idle
        case running
        /// Background running isn't available; gestures only work while the screen is on.
        case unavailable(String)
    }

    @Published private(set) var state = State.idle

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var wantsRunning = false

    func begin() async {
        wantsRunning = true
        guard session == nil else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            state = .unavailable("Health is not available on this device")
            return
        }

        do {
            // Starting a workout session requires permission to write workouts,
            // even though this app never writes one.
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            guard wantsRunning, session == nil else { return }

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .basketball
            configuration.locationType = .unknown
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            session.delegate = self
            session.startActivity(with: Date())
            self.session = session
            state = .running
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }

    func end() {
        wantsRunning = false
        session?.end()
        session = nil
        if state == .running { state = .idle }
    }
}

extension WorkoutRuntime: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let reason = error.localizedDescription
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard self.session === workoutSession else { return }
                self.session = nil
                self.state = .unavailable(reason)
            }
        }
    }
}
