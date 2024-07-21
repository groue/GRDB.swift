import GRDBQuery
import SwiftUI

@main
struct GRDBAsyncDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AppView().appDatabase(.shared)
        }
    }
}

// MARK: - Give SwiftUI access to the database

private struct AppDatabaseKey: EnvironmentKey {
    static var defaultValue: AppDatabase { .empty() }
}

extension EnvironmentValues {
    var appDatabase: AppDatabase {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}

extension View {
    func appDatabase(_ appDatabase: AppDatabase) -> some View {
        self
            .environment(\.appDatabase, appDatabase)
            .databaseContext(.readOnly { appDatabase.reader })
    }
}
