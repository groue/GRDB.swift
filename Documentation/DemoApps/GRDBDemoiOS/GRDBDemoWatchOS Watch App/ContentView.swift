import SwiftUI
import GRDB

struct ContentView: View {
    @State var sqliteVersion = ""
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("SQLite Version")
            Text(sqliteVersion)
        }
        .padding()
        .onAppear {
            do {
                sqliteVersion = try DatabaseQueue().read { db in
                    try String.fetchOne(db, sql: "SELECT SQLITE_VERSION()")!
                }
            } catch {
                sqliteVersion = String(describing: error)
            }
        }
    }
}

#Preview {
    ContentView()
}
