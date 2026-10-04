import SwiftUI
import WatchKit

@main
struct HoopTrackWatchApp: App {
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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
