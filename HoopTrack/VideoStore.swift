import Foundation

struct RecordedVideo: Equatable {
    let url: URL
    /// When the camera actually began writing frames.
    let startDate: Date
}

enum VideoSettings {
    private static let offsetKey = "video.shotOffset"

    /// Seconds between the ball leaving the hand and the shot being logged.
    /// Seeking to a shot lands this far before the moment it was logged.
    static var shotOffset: TimeInterval {
        get { UserDefaults.standard.object(forKey: offsetKey) as? Double ?? 4 }
        set { UserDefaults.standard.set(newValue, forKey: offsetKey) }
    }
}

enum VideoTimestamp {
    /// Where in the video to start watching a shot, in seconds from the start.
    static func seconds(shotDate: Date, videoStart: Date, offset: TimeInterval) -> Double {
        max(0, shotDate.timeIntervalSince(videoStart) - offset)
    }
}

/// Workout videos live in Documents/Videos and never leave the device.
enum VideoStore {
    static var directory: URL {
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Videos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            // Keep videos out of iCloud and device backups.
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return url
    }

    static func newURL(for workoutID: UUID) -> URL {
        directory.appendingPathComponent("\(workoutID.uuidString).mov")
    }

    static func discard(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

extension Workout {
    /// The workout's video if one was recorded and the file still exists.
    /// Resolved by file name, because the app's folder path changes between installs.
    var videoURL: URL? {
        guard let name = videoFileURL?.lastPathComponent else { return nil }
        let url = VideoStore.directory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
