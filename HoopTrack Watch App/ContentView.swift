import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "basketball.fill")
                .foregroundStyle(.orange)
            Text("HoopTrack")
                .font(.headline)
        }
    }
}

#Preview {
    ContentView()
}
