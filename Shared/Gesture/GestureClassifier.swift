import Foundation

enum GestureSensitivity: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var config: GestureConfig {
        switch self {
        case .low: GestureConfig(rateThreshold: 7.0, minAngle: 0.70)
        case .medium: GestureConfig(rateThreshold: 5.0, minAngle: 0.50)
        case .high: GestureConfig(rateThreshold: 3.5, minAngle: 0.35)
        }
    }
}

struct GestureConfig: Equatable {
    /// Roll rate (rad/s) that starts a candidate gesture.
    var rateThreshold: Double
    /// Rotation (rad) the wrist must cover for the gesture to count.
    var minAngle: Double
    /// The flick must be over within this long, or it is treated as ordinary arm movement.
    var maxDuration: TimeInterval = 0.3
    /// Samples are ignored for this long after a detection.
    var cooldown: TimeInterval = 1.5
    /// The gesture ends once the rate falls below this fraction of the threshold.
    var releaseFraction: Double = 0.4
}

/// Turns a stream of wrist roll rates into make/miss gestures.
/// Positive rate = wrist rotating away from the body (make);
/// negative = toward the body (miss).
struct GestureClassifier {
    var config: GestureConfig

    private enum State {
        case idle
        case tracking(start: TimeInterval, direction: Double, angle: Double)
        /// A movement ran too long; wait for the wrist to settle before listening again.
        case blocked
    }

    private var state = State.idle
    private var lastTime: TimeInterval?
    private var cooldownUntil: TimeInterval?

    init(config: GestureConfig = GestureSensitivity.medium.config) {
        self.config = config
    }

    mutating func reset() {
        state = .idle
        lastTime = nil
        cooldownUntil = nil
    }

    mutating func process(rate: Double, at time: TimeInterval) -> ShotResult? {
        let dt = min(max(0, time - (lastTime ?? time)), 0.1)
        lastTime = time

        if let until = cooldownUntil {
            guard time >= until else { return nil }
            cooldownUntil = nil
            // Don't pick up a movement that began during the cooldown mid-swing.
            state = abs(rate) >= releaseRate ? .blocked : .idle
        }

        switch state {
        case .idle:
            if abs(rate) >= config.rateThreshold {
                state = .tracking(start: time, direction: rate > 0 ? 1 : -1, angle: abs(rate) * dt)
            }
            return nil

        case .tracking(let start, let direction, let angle):
            let duration = time - start
            if rate * direction >= releaseRate {
                state = duration > config.maxDuration
                    ? .blocked
                    : .tracking(start: start, direction: direction, angle: angle + abs(rate) * dt)
                return nil
            }
            state = .idle
            guard duration <= config.maxDuration, angle >= config.minAngle else { return nil }
            cooldownUntil = time + config.cooldown
            return direction > 0 ? .made : .missed

        case .blocked:
            if abs(rate) < releaseRate { state = .idle }
            return nil
        }
    }

    private var releaseRate: Double { config.rateThreshold * config.releaseFraction }
}
