import SwiftUI

// Placeholder screens: unstyled on purpose. Each one only reads from
// WorkoutSession and calls its methods.
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

struct HomeView: View {
    @ObservedObject private var session = WorkoutSession.shared
    @ObservedObject private var connectivity = ConnectivityManager.shared

    var body: some View {
        VStack {
            Text("HoopTrack")
            Button("Start Workout") {
                session.start(type: .freeShoot)
            }
            Text(connectivity.isReachable ? "iPhone Connected" : "iPhone Not Reachable")
                .font(.caption2)
        }
    }
}

struct LiveSessionView: View {
    let workout: LiveWorkout
    @ObservedObject private var session = WorkoutSession.shared

    var body: some View {
        ScrollView {
            VStack {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(StatFormat.clock(workout.elapsed(at: context.date)))
                }
                Text(StatFormat.percent(workout.shootingPct))
                    .font(.title)
                Text("\(workout.makes)/\(workout.attempts)")
                Text("Streak \(workout.currentStreak) · Best \(workout.bestStreak)")
                    .font(.caption2)
                HStack {
                    Button("Make") { session.logMake() }
                    Button("Miss") { session.logMiss() }
                }
                Button("Undo") { session.undo() }
                    .disabled(workout.lastShot == nil)
                Button("End", role: .destructive) { session.end() }
            }
        }
    }
}

struct SummaryView: View {
    let summary: WorkoutSummary
    @ObservedObject private var session = WorkoutSession.shared

    var body: some View {
        ScrollView {
            VStack {
                Text(StatFormat.percent(summary.shootingPct))
                    .font(.title)
                Text("\(summary.makes)/\(summary.attempts)")
                Text("Best streak \(summary.bestStreak)")
                Text(StatFormat.clock(summary.duration))
                Button("Done") { session.dismissSummary() }
            }
        }
    }
}

#Preview {
    ContentView()
}
