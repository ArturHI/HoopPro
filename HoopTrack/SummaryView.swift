import SwiftUI

struct SummaryView: View {
    let summary: WorkoutSummary
    @ObservedObject private var session = WorkoutSession.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Workout Complete")
            Text(summary.workoutType.displayName)
            Text(StatFormat.percent(summary.shootingPct))
                .font(.largeTitle)
            Text("\(summary.makes) makes · \(summary.misses) misses")
            Text("Best streak \(summary.bestStreak)")
            Text(StatFormat.clock(summary.duration))
            Button("Done") { session.dismissSummary() }
        }
        .padding()
    }
}
