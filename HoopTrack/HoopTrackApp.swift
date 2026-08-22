import SwiftUI
import SwiftData

@main
struct HoopTrackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Workout.self, ShotEvent.self])
    }
}
