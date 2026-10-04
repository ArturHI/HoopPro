import SwiftUI

// Placeholder screens: unstyled on purpose. Each one only reads from
// WorkoutSession / SwiftData and calls WorkoutSession methods.
struct ContentView: View {
    @ObservedObject private var session = WorkoutSession.shared

    var body: some View {
        if let workout = session.workout {
            LiveSessionView(workout: workout)
        } else if let summary = session.lastSummary {
            SummaryView(summary: summary)
        } else {
            HomeView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Workout.self, ShotEvent.self], inMemory: true)
}
