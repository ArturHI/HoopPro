import SwiftUI

struct ContentView: View {
    @StateObject private var connectivity = ConnectivityManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("HoopTrack")
                .font(.largeTitle.bold())
            Label(
                connectivity.isReachable ? "Watch Connected" : "Watch Not Reachable",
                systemImage: connectivity.isReachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash"
            )
            .font(.subheadline)
            .foregroundStyle(connectivity.isReachable ? .green : .secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
