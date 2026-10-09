import SwiftUI

struct LiveSessionView: View {
    let workout: LiveWorkout
    @ObservedObject private var session = WorkoutSession.shared
    @ObservedObject private var recorder = VideoRecorder.shared

    var body: some View {
        VStack(spacing: 16) {
            Text(workout.workoutType.displayName)
            switch recorder.state {
            case .recording:
                Text("● Recording")
                CameraPreview(layer: recorder.previewLayer)
                    .frame(height: 160)
            case .starting:
                Text("Starting camera…")
            case .failed(let reason):
                Text("Video off: \(reason)")
            case .idle:
                EmptyView()
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(StatFormat.clock(workout.elapsed(at: context.date)))
            }
            Text(StatFormat.percent(workout.shootingPct))
                .font(.largeTitle)
            Text("\(workout.makes)/\(workout.attempts)")
            Text("Streak \(workout.currentStreak) · Best \(workout.bestStreak)")

            HStack {
                Button("Make") { session.logMake() }
                Button("Miss") { session.logMiss() }
            }
            .buttonStyle(.borderedProminent)

            Button("Undo") { session.undo() }
                .disabled(workout.lastShot == nil)
            Button("End Workout", role: .destructive) { session.end() }
        }
        .padding()
    }
}
