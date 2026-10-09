import SwiftUI

// Placeholder: live rotation values for tuning gestures on a real Watch.
struct GestureDebugView: View {
    @ObservedObject private var detector = GestureDetector.shared
    @ObservedObject private var runtime = WorkoutRuntime.shared

    var body: some View {
        List {
            Section("Live") {
                if !detector.isAvailable {
                    Text("Motion not available on this device")
                } else if let sample = detector.latest {
                    Text("Roll \(sample.rollRate, specifier: "%+.2f") rad/s")
                    Text("x \(sample.x, specifier: "%+.2f")  y \(sample.y, specifier: "%+.2f")  z \(sample.z, specifier: "%+.2f")")
                } else {
                    Text("Waiting for motion…")
                }
                if let result = detector.lastDetection, let date = detector.lastDetectionDate {
                    Text("Last: \(result == .made ? "MAKE" : "MISS") at \(date, format: .dateTime.hour().minute().second())")
                } else {
                    Text("Last: none")
                }
            }

            Section("Wrist-down running") {
                switch runtime.state {
                case .idle: Text("Starts with a workout")
                case .running: Text("Running")
                case .unavailable(let reason): Text("Off: \(reason)")
                }
            }

            Section("Settings") {
                Toggle("Gestures log shots", isOn: $detector.isEnabled)
                Picker("Sensitivity", selection: $detector.sensitivity) {
                    ForEach(GestureSensitivity.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                Toggle("Swap make / miss", isOn: $detector.isInverted)
            }
        }
        .navigationTitle("Gestures")
        .onAppear { detector.begin(.debug) }
        .onDisappear { detector.end(.debug) }
    }
}
