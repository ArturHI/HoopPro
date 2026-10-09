import SwiftUI
import SwiftData
import AVKit

// Placeholder: the recorded video with the shot list; tap a shot to jump to it.
struct VideoReviewView: View {
    let workout: Workout
    let videoURL: URL
    @State private var player: AVPlayer

    init(workout: Workout, videoURL: URL) {
        self.workout = workout
        self.videoURL = videoURL
        _player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        VStack(spacing: 0) {
            VideoPlayer(player: player)
                .frame(height: 240)
            List {
                ShotListSection(workout: workout) { shot in
                    guard let seconds = shot.videoTimestamp else { return }
                    player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                    player.play()
                }
            }
        }
        .navigationTitle("Video Review")
        .onDisappear { player.pause() }
    }
}

/// Shot-by-shot list with correction controls. `onSelect` fires when a row is tapped.
struct ShotListSection: View {
    let workout: Workout
    var onSelect: ((ShotEvent) -> Void)?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Section("Shots") {
            ForEach(workout.orderedShots) { shot in
                HStack {
                    Button {
                        onSelect?(shot)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("#\(shot.shotNumber)  \(label(for: shot))")
                            if let seconds = shot.videoTimestamp {
                                Text(StatFormat.clock(seconds)).font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Menu("Edit") {
                        Button("Made") { apply { workout.setResult(.made, for: shot) } }
                        Button("Missed") { apply { workout.setResult(.missed, for: shot) } }
                        if shot.isExcluded {
                            Button("Restore shot") { apply { workout.setExcluded(false, for: shot) } }
                        } else {
                            Button("Not a shot") { apply { workout.setExcluded(true, for: shot) } }
                        }
                    }
                }
            }
        }
    }

    private func label(for shot: ShotEvent) -> String {
        if shot.isExcluded { return "Not a shot" }
        let result = shot.result == .made ? "Make" : "Miss"
        return shot.corrected ? "\(result) (corrected)" : result
    }

    private func apply(_ change: () -> Void) {
        change()
        try? modelContext.save()
    }
}
