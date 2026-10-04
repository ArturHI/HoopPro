import SwiftUI
import SwiftData
import Charts

// Placeholder: progress over time, computed by ProgressStats.
struct TrendsView: View {
    @Query private var workouts: [Workout]
    @State private var type: WorkoutType?

    var body: some View {
        let stats = ProgressStats(workouts: workouts, type: type)

        List {
            Picker("Type", selection: $type) {
                Text("All").tag(WorkoutType?.none)
                ForEach(WorkoutType.allCases) { type in
                    Text(type.displayName).tag(WorkoutType?.some(type))
                }
            }

            Section("Trend") {
                if stats.trend.isEmpty {
                    Text("No workouts yet")
                } else {
                    Chart(stats.trend) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Shooting", point.shootingPct * 100))
                        PointMark(x: .value("Date", point.date), y: .value("Shooting", point.shootingPct * 100))
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 180)
                }
            }

            Section("Compared") {
                if let comparison = stats.latestVsPrevious {
                    LabeledContent("Last session", value: StatFormat.percent(comparison.latestPct))
                    LabeledContent("Session before", value: StatFormat.percent(comparison.previousPct))
                    LabeledContent("Change", value: StatFormat.signedPoints(comparison.change))
                } else {
                    Text("Needs two workouts")
                }
            }

            Section("Weeks") {
                LabeledContent("This week", value: summary(stats.thisWeek))
                LabeledContent("Last week", value: summary(stats.lastWeek))
                if let change = stats.weekOverWeekChange {
                    LabeledContent("Change", value: StatFormat.signedPoints(change))
                }
            }

            Section("Personal bests") {
                LabeledContent("Best shooting", value: stats.bestShootingPct.map { StatFormat.percent($0.value) } ?? "–")
                LabeledContent("Longest streak", value: stats.longestStreak.map { "\($0.value)" } ?? "–")
                LabeledContent("Most makes", value: stats.mostMakes.map { "\($0.value)" } ?? "–")
            }

            Section("All time") {
                LabeledContent("Workouts", value: "\(stats.allTime.workouts)")
                LabeledContent("Shots", value: summary(stats.allTime))
            }
        }
        .navigationTitle("Progress")
    }

    private func summary(_ totals: PeriodTotals) -> String {
        totals.attempts == 0 ? "–" : "\(totals.makes)/\(totals.attempts) · \(StatFormat.percent(totals.shootingPct))"
    }
}
