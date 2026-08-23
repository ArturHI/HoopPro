import SwiftUI

struct ContentView: View {
    @StateObject private var connectivity = ConnectivityManager.shared

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "basketball.fill")
                .foregroundStyle(.orange)
            Text("HoopTrack")
                .font(.headline)
            Label(
                connectivity.isReachable ? "Connected" : "Not Reachable",
                systemImage: connectivity.isReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash"
            )
            .font(.caption2)
            .foregroundStyle(connectivity.isReachable ? .green : .secondary)
        }
    }
}

#Preview {
    ContentView()
}
