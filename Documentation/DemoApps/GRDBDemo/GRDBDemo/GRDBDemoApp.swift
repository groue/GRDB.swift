import SwiftUI

@main
struct GRDBDemoApp: App {
    var body: some Scene {
        WindowGroup {
            PlayersNavigationView().appDatabase(.shared)
        }
    }
}

// MARK: - Give SwiftUI access to the database

extension EnvironmentValues {
    @Entry var appDatabase = AppDatabase.empty()
}

extension View {
    func appDatabase(_ appDatabase: AppDatabase) -> some View {
        self.environment(\.appDatabase, appDatabase)
    }
}
