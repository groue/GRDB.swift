import GRDB
import SwiftUI

@main
struct GRDBManualInstallApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("SQLite version: \(sqliteVersion)")
            }
            .padding()
        }
    }
    
    var sqliteVersion: String {
        do {
            return try DatabaseQueue().read { db in
                try String.fetchOne(db, sql: "SELECT sqlite_version()")!
            }
        } catch {
            return "error"
        }
    }
}
