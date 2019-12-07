import Dispatch
import Foundation
import GRDB
import os.log

class AppDatabase {
    static let shared = AppDatabase()
    var dbWriter: DatabaseWriter?
    
    func createDatabaseQueue() throws {
        dbWriter = nil
        try resetDatabaseDirectoy()
        dbWriter = try DatabaseQueue(path: databasePath, configuration: configuration)
        try migrator.migrate(dbWriter!)
    }
    
    func createDatabasePool() throws {
        dbWriter = nil
        try resetDatabaseDirectoy()
        dbWriter = try DatabasePool(path: databasePath, configuration: configuration)
        try migrator.migrate(dbWriter!)
    }
    
    func openLongRunningTransaction(until promise: (@escaping () -> Void) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        let dbWriter = self.dbWriter!
        let semaphore = DispatchSemaphore(value: 0)
        promise({ semaphore.signal() })
        
        DispatchQueue.global().async {
            let result = Result {
                try dbWriter.writeWithoutTransaction { db in
                    try db.inTransaction(.immediate) {
                        semaphore.wait()
                        return .commit
                    }
                }
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        // TODO: why doen't this reproduce the bug??
        //        dbWriter.asyncWrite({ _ in
        //            semaphore.wait()
        //        }, completion: { (_, result) in
        //            DispatchQueue.main.async {
        //                completion(result)
        //            }
        //        })
    }
    
    func openLongRunningTransaction(completion: @escaping (Result<Void, Error>) -> Void) {
        let dbWriter = self.dbWriter!
        
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global().async {
            let result = Result {
                try dbWriter.writeWithoutTransaction { db in
                    try db.inTransaction(.immediate) {
                        semaphore.wait()
                        return .commit
                    }
                }
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        // TODO: why doen't this reproduce the bug??
//        dbWriter.asyncWrite({ _ in
//            semaphore.wait()
//        }, completion: { (_, result) in
//            DispatchQueue.main.async {
//                completion(result)
//            }
//        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(60)) {
            semaphore.signal()
        }
    }
    
    func runLongQuery(completion: @escaping (Result<Void, Error>) -> Void) {
        let dbWriter = self.dbWriter!
        
        let semaphore = DispatchSemaphore(value: 0)
        dbWriter.add(function: DatabaseFunction("wait", argumentCount: 1, pure: true) { _ in
            semaphore.wait()
            return nil
        })
        
        DispatchQueue.global().async {
            let result = Result {
                try dbWriter.writeWithoutTransaction { db in
                    _ = try Row.fetchOne(db, sql: "SELECT wait(name) FROM player")
                }
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(60)) {
            semaphore.signal()
        }
    }
    
    private var databaseDirectorURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.github.groue.GRDB.AppGroupTest")!
            .appendingPathComponent("database", isDirectory: true)
    }
    
    private var databasePath: String {
        databaseDirectorURL.appendingPathComponent("db.sqlite").path
    }

    private func resetDatabaseDirectoy() throws {
        let fm = FileManager()
        let dirURL = databaseDirectorURL
        if fm.fileExists(atPath: dirURL.path) {
            for name in try fm.contentsOfDirectory(atPath: dirURL.path) {
                try fm.removeItem(at: dirURL.appendingPathComponent(name))
            }
        }
        try fm.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    private var configuration: Configuration {
        var configuration = Configuration()
        configuration.trace = {
            os_log("SQL> %@", $0)
        }
        return configuration
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPlayer") { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("score", .integer).notNull()
            }
            try db.execute(sql: "INSERT INTO player (name, score) VALUES ('foo', 0)")
        }
        return migrator
    }
}
