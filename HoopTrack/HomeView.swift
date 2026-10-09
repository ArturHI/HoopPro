import SwiftUI
import SwiftData

struct HomeView: View {
    @ObservedObject private var session = WorkoutSession.shared
    @ObservedObject private var connectivity = ConnectivityManager.shared
    @ObservedObject private var recorder = VideoRecorder.shared
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
                    Toggle("Record video", isOn: $recorder.isEnabled)
                        .disabled(!recorder.isCameraAvailable)
                    if recorder.isEnabled {
                        CameraPreview(session: recorder.captureSession)
                            .frame(height: 200)
                        if case .failed(let reason) = recorder.state {
                            Text(reason)
                        }
                    }
                    Button("Start Workout") {
                        session.start(type: workoutType)
                    }
                }
                .onChange(of: recorder.isEnabled) { _, isOn in
                    if isOn {
                        Task { await recorder.prepare() }
                    } else {
                        recorder.shutDown()
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
