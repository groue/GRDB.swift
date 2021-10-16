import GRDB
import SwiftUI

@main
struct GRDBAsyncDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AppView().environment(\.appDatabase, .shared)
        }
    }
}

// Let SwiftUI views access the app database through the SwiftUI environment
private struct AppDatabaseKey: EnvironmentKey {
    /// Default appDatabase is an empty in-memory database
    static var defaultValue: AppDatabase { .empty() }
}

extension EnvironmentValues {
    var appDatabase: AppDatabase {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}
