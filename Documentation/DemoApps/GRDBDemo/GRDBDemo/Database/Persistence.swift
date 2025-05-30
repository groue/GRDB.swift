import Foundation
import GRDB

extension AppDatabase {
    /// The database for the application
    static let shared = makeShared()
    
    private static func makeShared() -> AppDatabase {
        do {
            // Apply recommendations from
            // <https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseconnections>
            
            // Create the "Application Support/Database" directory if needed
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            let directoryURL = appSupportURL.appendingPathComponent("Database", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            // Open or create the database
            let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
            let config = AppDatabase.makeConfiguration()
            let dbPool = try DatabasePool(path: databaseURL.path, configuration: config)
            
            // Create the AppDatabase
            let appDatabase = try AppDatabase(dbPool)
            
            // Populate the database if it is empty, for better demo purpose.
            try appDatabase.createRandomPlayersIfEmpty()
            
            return appDatabase
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate.
            //
            // Typical reasons for an error here include:
            // * The parent directory cannot be created, or disallows writing.
            // * The database is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The database could not be migrated to its latest schema version.
            // Check the error message to determine what the actual problem was.
            fatalError("Unresolved error \(error)")
        }
    }
    
    /// Creates an empty database for SwiftUI previews
    static func empty() -> AppDatabase {
        // Connect to an in-memory database
        // See https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseconnections
        let dbQueue = try! DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try! AppDatabase(dbQueue)
    }
    
    /// Creates a database full of random players for SwiftUI previews
    static func random() -> AppDatabase {
        let appDatabase = empty()
        try! appDatabase.createRandomPlayersIfEmpty()
        return appDatabase
    }
}
