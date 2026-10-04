import Foundation

/// What the two devices tell each other during a workout. Every event is
/// safe to receive twice: shots and workouts are matched by id.
enum SessionEvent: Codable, Equatable {
    case start(LiveWorkout)
    case shot(workoutID: UUID, shot: LiveShot)
    case undo(workoutID: UUID, shotID: UUID)
    case end(workoutID: UUID, endDate: Date)
    /// Asks the peer to reply with `.start` if it has a workout in progress.
    case requestSync

    private static let payloadKey = "event"

    var payload: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return [Self.payloadKey: data]
    }

    init?(payload: [String: Any]) {
        guard let data = payload[Self.payloadKey] as? Data,
              let event = try? JSONDecoder().decode(SessionEvent.self, from: data) else { return nil }
        self = event
    }
}
