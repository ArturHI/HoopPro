import SwiftUI

@main
struct HoopTrackWatchApp: App {
    init() {
        ConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
