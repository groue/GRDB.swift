import GRDB
import SwiftUI

@main
struct GRDBCombineDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AppView().environment(\.appDatabase, AppDatabase.shared)
        }
    }
}

// Let SwiftUI views access the database through the SwiftUI environment
private struct AppDatabaseKey: EnvironmentKey {
    static let defaultValue: AppDatabase? = nil
}

extension EnvironmentValues {
    var appDatabase: AppDatabase? {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}
