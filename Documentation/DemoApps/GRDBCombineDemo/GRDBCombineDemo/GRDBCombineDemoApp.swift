import GRDB
import SwiftUI

@main
struct GRDBCombineDemoApp: App {
    @State var initialOrdering: PlayerRequest.Ordering = .byName

    var body: some Scene {
        WindowGroup {
            AppView(initialOrdering: initialOrdering)
                .environment(\.appDatabase, AppDatabase.shared)
                .onAppear {
                    initialOrdering = .byScore
                }
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
