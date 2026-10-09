import SwiftUI

// Placeholder: one saved workout and its shot-by-shot list.
struct SessionDetailView: View {
    let workout: Workout

    var body: some View {
        List {
            Section("Stats") {
                LabeledContent("Type", value: workout.workoutType.displayName)
                LabeledContent("Date", value: workout.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Shooting", value: StatFormat.percent(workout.shootingPct))
                LabeledContent("Makes", value: "\(workout.totalMakes)")
                LabeledContent("Misses", value: "\(workout.totalMisses)")
                LabeledContent("Best streak", value: "\(workout.bestStreak)")
                LabeledContent("Duration", value: StatFormat.clock(workout.duration))
            }

            if let videoURL = workout.videoURL {
                Section {
                    NavigationLink("Review Video") {
                        VideoReviewView(workout: workout, videoURL: videoURL)
                    }
                }
            }

            ShotListSection(workout: workout)
        }
        .navigationTitle("Workout")
    }
}
