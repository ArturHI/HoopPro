import SwiftUI
import SwiftData

struct HomeView: View {
    @ObservedObject private var session = WorkoutSession.shared
    @ObservedObject private var connectivity = ConnectivityManager.shared
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @State private var workoutType: WorkoutType = .freeShoot

    var body: some View {
        NavigationStack {
            List {
                Section("New Workout") {
                    Picker("Type", selection: $workoutType) {
                        ForEach(WorkoutType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    Button("Start Workout") {
                        session.start(type: workoutType)
                    }
                }

                Section("Today") {
                    let today = ProgressStats(workouts: workouts).today
                    if today.attempts == 0 {
                        Text("No shots today")
                    } else {
                        Text("\(today.makes)/\(today.attempts) · \(StatFormat.percent(today.shootingPct)) · \(today.workouts) workouts")
                    }
                }

                Section("Recent") {
                    if workouts.isEmpty {
                        Text("No workouts yet")
                    }
                    ForEach(workouts.prefix(3)) { workout in
                        NavigationLink {
                            SessionDetailView(workout: workout)
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                    }
                    NavigationLink("All History") { HistoryView() }
                    NavigationLink("Progress") { TrendsView() }
                }

                Section {
                    Text(connectivity.isReachable ? "Watch Connected" : "Watch Not Reachable")
                }
            }
            .navigationTitle("HoopTrack")
        }
    }
}
