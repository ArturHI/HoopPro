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

                Section("Recent") {
                    if workouts.isEmpty {
                        Text("No workouts yet")
                    }
                    ForEach(workouts) { workout in
                        VStack(alignment: .leading) {
                            Text(workout.workoutType.displayName)
                            Text("\(workout.totalMakes)/\(workout.totalAttempts) · \(StatFormat.percent(workout.shootingPct)) · \(StatFormat.clock(workout.duration))")
                            Text(workout.date, format: .dateTime.month().day().hour().minute())
                        }
                    }
                }

                Section {
                    Text(connectivity.isReachable ? "Watch Connected" : "Watch Not Reachable")
                }
            }
            .navigationTitle("HoopTrack")
        }
    }
}
