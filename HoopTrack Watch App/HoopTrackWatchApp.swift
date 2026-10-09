import SwiftUI
import WatchKit
import Combine

@main
struct HoopTrackWatchApp: App {
    private let workoutObserver: AnyCancellable

    init() {
        let session = WorkoutSession.shared
        let connectivity = ConnectivityManager.shared
        session.send = { connectivity.send($0) }
        session.onLocalShot = { shot in
            WKInterfaceDevice.current().play(shot.result == .made ? .success : .failure)
        }
        connectivity.onEvent = { session.handle($0) }
        connectivity.activate()
        session.requestSync()

        // Gestures only register while a workout is running; the workout
        // session keeps them running with the wrist down.
        let runtime = WorkoutRuntime.shared
        let detector = GestureDetector.shared
        detector.onGesture = { session.logShot($0, source: .watchGesture) }
        workoutObserver = session.$workout
            .map { $0 != nil }
            .removeDuplicates()
            .sink { isActive in
                if isActive {
                    detector.begin(.workout)
                    Task { await runtime.begin() }
                } else {
                    detector.end(.workout)
                    runtime.end()
                }
            }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
