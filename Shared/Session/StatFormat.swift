import Foundation

enum StatFormat {
    /// "4:07", or "1:04:07" past an hour.
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// "67%" from a 0...1 fraction.
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// "+5 pts" / "-3 pts" from a 0...1 difference between two percentages.
    static func signedPoints(_ change: Double) -> String {
        let points = Int((change * 100).rounded())
        return "\(points > 0 ? "+" : "")\(points) pts"
    }
}
