import SwiftUI
import GRDB

struct ContentView: View {
    var body: some View {
        VStack {
            Text("SQLCipher version: \(cipherVersion)")
        }
        .padding()
    }

    private var cipherVersion: String {
        try! DatabaseQueue().read { try $0.cipherVersion }
    }
}

#Preview {
    ContentView()
}
