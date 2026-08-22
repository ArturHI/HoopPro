import Foundation

enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case freeShoot
    case freeThrow
    case challenge100
    case fiveSpot
    case midrange
    case threePointer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .freeShoot: "Free Shooting"
        case .freeThrow: "Free Throws"
        case .challenge100: "100-Shot Challenge"
        case .fiveSpot: "5-Spot Shooting"
        case .midrange: "Midrange"
        case .threePointer: "Three-Pointers"
        }
    }
}
