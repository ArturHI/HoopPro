import Foundation
import CoreMotion
import WatchKit

struct MotionSample: Equatable {
    /// Raw gyroscope rates in rad/s, in the Watch's own axes.
    let x: Double
    let y: Double
    let z: Double
    /// Roll around the forearm, signed so positive = away from the body.
    let rollRate: Double
}

/// Reads wrist motion and reports make/miss gestures.
@MainActor
final class GestureDetector: ObservableObject {
    static let shared = GestureDetector()

    enum Consumer: Hashable { case workout, debug }

    @Published private(set) var isAvailable: Bool
    @Published private(set) var isRunning = false
    @Published private(set) var latest: MotionSample?
    @Published private(set) var lastDetection: ShotResult?
    @Published private(set) var lastDetectionDate: Date?

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }
    @Published var sensitivity: GestureSensitivity {
        didSet {
            defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity)
            classifier.config = sensitivity.config
        }
    }
    /// Flips make and miss, in case the wrist/crown setup reads backwards.
    @Published var isInverted: Bool {
        didSet { defaults.set(isInverted, forKey: Keys.inverted) }
    }

    var onGesture: ((ShotResult) -> Void)?

    private enum Keys {
        static let enabled = "gesture.enabled"
        static let sensitivity = "gesture.sensitivity"
        static let inverted = "gesture.inverted"
    }

    private let motion = CMMotionManager()
    private let defaults: UserDefaults
    private var classifier: GestureClassifier
    private var consumers: Set<Consumer> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let sensitivity = defaults.string(forKey: Keys.sensitivity).flatMap(GestureSensitivity.init) ?? .medium
        self.sensitivity = sensitivity
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        isInverted = defaults.bool(forKey: Keys.inverted)
        classifier = GestureClassifier(config: sensitivity.config)
        isAvailable = motion.isDeviceMotionAvailable
    }

    func begin(_ consumer: Consumer) {
        consumers.insert(consumer)
        updateRunning()
    }

    func end(_ consumer: Consumer) {
        consumers.remove(consumer)
        updateRunning()
    }

    private func updateRunning() {
        let shouldRun = !consumers.isEmpty && motion.isDeviceMotionAvailable
        guard shouldRun != isRunning else { return }
        isRunning = shouldRun

        guard shouldRun else {
            motion.stopDeviceMotionUpdates()
            latest = nil
            return
        }
        classifier.reset()
        motion.deviceMotionUpdateInterval = 1.0 / 50.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            MainActor.assumeIsolated {
                self?.handle(data)
            }
        }
    }

    private func handle(_ data: CMDeviceMotion) {
        let rate = data.rotationRate
        let roll = rate.x * awayFromBodySign
        latest = MotionSample(x: rate.x, y: rate.y, z: rate.z, rollRate: roll)

        guard let result = classifier.process(rate: roll, at: data.timestamp) else { return }
        lastDetection = result
        lastDetectionDate = Date()
        if isEnabled { onGesture?(result) }
    }

    /// The forearm runs along the Watch's x axis. Rolling the wrist away from
    /// the body reads negative with the crown on the right and positive with
    /// it on the left, on either wrist (the two setups are mirror images).
    private var awayFromBodySign: Double {
        let base: Double = WKInterfaceDevice.current().crownOrientation == .right ? -1 : 1
        return isInverted ? -base : base
    }
}
