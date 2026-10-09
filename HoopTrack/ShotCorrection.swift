import Foundation

extension Workout {
    /// Changes a shot between made and missed, remembering what it was first logged as.
    func setResult(_ result: ShotResult, for shot: ShotEvent) {
        guard shot.result != result else { return }
        if shot.originalResult == result {
            // Corrected back to how it was logged.
            shot.originalResult = nil
            shot.corrected = false
        } else {
            shot.originalResult = shot.originalResult ?? shot.result
            shot.corrected = true
        }
        shot.result = result
        recalculateStats()
    }

    /// Marks a shot "not a shot" (or restores it). It stays in the list but
    /// no longer counts toward any stat.
    func setExcluded(_ excluded: Bool, for shot: ShotEvent) {
        guard shot.isExcluded != excluded else { return }
        shot.isExcluded = excluded
        recalculateStats()
    }

    func recalculateStats() {
        let counted = orderedShots.filter { !$0.isExcluded }
        var best = 0
        var run = 0
        for shot in counted {
            run = shot.result == .made ? run + 1 : 0
            best = max(best, run)
        }
        totalAttempts = counted.count
        totalMakes = counted.filter { $0.result == .made }.count
        shootingPct = counted.isEmpty ? 0 : Double(totalMakes) / Double(totalAttempts)
        bestStreak = best
    }
}
