import SwiftUI
import SwiftData

// Placeholder: every saved workout, newest first.
struct HistoryView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    var body: some View {
        List {
            if workouts.isEmpty {
                Text("No workouts yet")
            }
            ForEach(workouts) { workout in
                NavigationLink {
                    SessionDetailView(workout: workout)
                } label: {
                    WorkoutRow(workout: workout)
                }
            }
        }
        .navigationTitle("History")
    }
}

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading) {
            Text(workout.workoutType.displayName)
            Text("\(workout.totalMakes)/\(workout.totalAttempts) · \(StatFormat.percent(workout.shootingPct)) · \(StatFormat.clock(workout.duration))")
            Text(workout.date, format: .dateTime.month().day().hour().minute())
        }
    }
}
