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

        // Gestures only register while a workout is running.
        let detector = GestureDetector.shared
        detector.onGesture = { session.logShot($0, source: .watchGesture) }
        workoutObserver = session.$workout
            .map { $0 != nil }
            .removeDuplicates()
            .sink { isActive in
                if isActive { detector.begin(.workout) } else { detector.end(.workout) }
            }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
