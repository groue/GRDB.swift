import GRDB

extension AppDatabase {
    /// The database for the application
    static let shared = makeShared()
    
    private static func makeShared() -> AppDatabase {
        do {
            // Create a folder for storing the SQLite database, as well as
            // the various temporary files created during normal database
            // operations (https://sqlite.org/tempfiles.html).
            let fileManager = FileManager()
            let folderURL = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("database", isDirectory: true)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            // Connect to a database on disk
            // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
            let dbURL = folderURL.appendingPathComponent("db.sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)
            
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
}
