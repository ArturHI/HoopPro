import SwiftUI
import SwiftData

@main
struct HoopTrackApp: App {
    init() {
        ConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Workout.self, ShotEvent.self])
    }
}
