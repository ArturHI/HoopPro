import SwiftUI
import SwiftData

@main
struct HoopTrackApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Workout.self, ShotEvent.self)
        } catch {
            fatalError("Could not open the workout store: \(error)")
        }

        let session = WorkoutSession.shared
        let connectivity = ConnectivityManager.shared
        session.send = { connectivity.send($0) }
        session.onFinish = { [container] workout, endDate in
            WorkoutRecorder.save(workout, endDate: endDate, in: container.mainContext)
        }
        connectivity.onEvent = { session.handle($0) }
        connectivity.activate()
        session.requestSync()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
