import GRDB
import Query
import SwiftUI

@main
struct QueryDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}

// MARK: - Give SwiftUI access to the database
//
// Define a new environment key that grants access to a DatabaseQueue.
//
// The technique is documented at
// <https://developer.apple.com/documentation/swiftui/environmentkey>.

private struct DatabaseQueueKey: EnvironmentKey {
    /// The default dbQueue is an empty in-memory database of players
    static let defaultValue = emptyDatabaseQueue()
}

extension EnvironmentValues {
    var dbQueue: DatabaseQueue {
        get { self[DatabaseQueueKey.self] }
        set { self[DatabaseQueueKey.self] = newValue }
    }
}

// In this demo app, views observe the database with the @Query property
// wrapper, defined in the local Query package. Its documentation recommends to
// define a dedicated initializer for `dbQueue` access, so we comply:

extension Query where Request.DatabaseContext == DatabaseQueue {
    init(_ request: Request) {
        self.init(request, in: \.dbQueue)
    }
}
