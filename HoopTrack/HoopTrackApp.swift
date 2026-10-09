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
        let recorder = VideoRecorder.shared
        session.onStart = { workout in
            guard recorder.isEnabled else { return }
            Task { await recorder.startRecording(workoutID: workout.id) }
        }
        session.onFinish = { [container] workout, endDate in
            let video = recorder.stopRecording()
            WorkoutRecorder.save(workout, endDate: endDate, video: video, in: container.mainContext)
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
