import XCTest
@testable import HoopTrack

final class GestureClassifierTests: XCTestCase {
    private let step = 1.0 / 50.0

    /// Feeds a half-sine flick peaking at `peak` rad/s over `duration`, then
    /// stillness, and returns every detection.
    private func feedFlick(
        into classifier: inout GestureClassifier,
        peak: Double,
        duration: TimeInterval,
        startingAt start: TimeInterval
    ) -> [ShotResult] {
        var results: [ShotResult] = []
        var time = start
        while time <= start + duration + 0.2 {
            let phase = (time - start) / duration
            let rate = phase <= 1 ? peak * sin(.pi * phase) : 0
            if let result = classifier.process(rate: rate, at: time) { results.append(result) }
            time += step
        }
        return results
    }

    func testQuickFlickAwayFromBodyIsAMake() {
        var classifier = GestureClassifier()
        XCTAssertEqual(feedFlick(into: &classifier, peak: 10, duration: 0.2, startingAt: 0), [.made])
    }

    func testQuickFlickTowardBodyIsAMiss() {
        var classifier = GestureClassifier()
        XCTAssertEqual(feedFlick(into: &classifier, peak: -10, duration: 0.2, startingAt: 0), [.missed])
    }

    func testGentleMovementIsIgnored() {
        var classifier = GestureClassifier()
        XCTAssertEqual(feedFlick(into: &classifier, peak: 3, duration: 0.2, startingAt: 0), [])
    }

    func testFastButTinyTwitchIsIgnored() {
        var classifier = GestureClassifier()
        // Crosses the rate threshold but covers far less than the minimum angle.
        XCTAssertEqual(feedFlick(into: &classifier, peak: 6, duration: 0.06, startingAt: 0), [])
    }

    func testSlowSustainedRotationIsIgnored() {
        var classifier = GestureClassifier()
        XCTAssertEqual(feedFlick(into: &classifier, peak: 8, duration: 0.8, startingAt: 0), [])
    }

    func testReboundDuringCooldownIsIgnoredAndNextGestureCounts() {
        var classifier = GestureClassifier()
        var results = feedFlick(into: &classifier, peak: 10, duration: 0.2, startingAt: 0)
        // The wrist snapping back right after the flick.
        results += feedFlick(into: &classifier, peak: -10, duration: 0.2, startingAt: 0.45)
        XCTAssertEqual(results, [.made])

        results += feedFlick(into: &classifier, peak: -10, duration: 0.2, startingAt: 2.5)
        XCTAssertEqual(results, [.made, .missed])
    }

    func testHigherSensitivityCatchesSofterFlicks() {
        var medium = GestureClassifier(config: GestureSensitivity.medium.config)
        var high = GestureClassifier(config: GestureSensitivity.high.config)
        XCTAssertEqual(feedFlick(into: &medium, peak: 4.5, duration: 0.2, startingAt: 0), [])
        XCTAssertEqual(feedFlick(into: &high, peak: 4.5, duration: 0.2, startingAt: 0), [.made])
    }
}
