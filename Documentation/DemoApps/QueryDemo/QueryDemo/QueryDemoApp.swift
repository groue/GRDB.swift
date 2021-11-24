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

let demoDatabaseQueue: DatabaseQueue = {
    let dbQueue = DatabaseQueue()
    try! dbQueue.write { db in
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer).notNull()
            t.column("photoID", .integer).notNull()
        }
        // insert a random player (and ignore generated id)
        _ = try Player.makeRandom().inserted(db)
    }
    return dbQueue
}()

private struct DatabaseQueueKey: EnvironmentKey {
    static var defaultValue: DatabaseQueue { demoDatabaseQueue }
}

extension EnvironmentValues {
    var dbQueue: DatabaseQueue {
        get { self[DatabaseQueueKey.self] }
        set { self[DatabaseQueueKey.self] = newValue }
    }
}

extension Query where QueryableType.DatabaseContext == DatabaseQueue {
    init(_ query: QueryableType) {
        self.init(query, in: \.dbQueue)
    }
}
