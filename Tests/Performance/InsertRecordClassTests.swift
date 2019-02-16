import XCTest
import GRDB
#if GRDB_COMPARE
import CoreData
import RealmSwift
#endif

private let insertedRowCount = 20_000

// Here we insert records.
class InsertRecordClassTests: XCTestCase {
    
    func testGRDB() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, insertedRowCount)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT MIN(i0) FROM items")!, 0)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT MAX(i9) FROM items")!, insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        measure {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            try! dbQueue.inTransaction { db in
                for i in 0..<insertedRowCount {
                    try ItemClass(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
                }
                return .commit
            }
        }
    }
    
    #if GRDB_COMPARE
    func testCoreData() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        let modelURL = Bundle(for: type(of: self)).url(forResource: "PerformanceModel", withExtension: "momd")!
        let mom = NSManagedObjectModel(contentsOf: modelURL)!
        
        measure {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
            let store = try! psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: URL(fileURLWithPath: databasePath), options: nil)
            let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            moc.persistentStoreCoordinator = psc
            
            for i in 0..<insertedRowCount {
                let item = NSEntityDescription.insertNewObject(forEntityName: "Item", into: moc)
                item.setValue(NSNumber(value: i), forKey: "i0")
                item.setValue(NSNumber(value: i), forKey: "i1")
                item.setValue(NSNumber(value: i), forKey: "i2")
                item.setValue(NSNumber(value: i), forKey: "i3")
                item.setValue(NSNumber(value: i), forKey: "i4")
                item.setValue(NSNumber(value: i), forKey: "i5")
                item.setValue(NSNumber(value: i), forKey: "i6")
                item.setValue(NSNumber(value: i), forKey: "i7")
                item.setValue(NSNumber(value: i), forKey: "i8")
                item.setValue(NSNumber(value: i), forKey: "i9")
            }
            try! moc.save()
            try! psc.remove(store)
            try! FileManager.default.removeItem(atPath: databasePath)
        }
    }
    
    func testRealm() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).realm"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        let databaseURL = URL(fileURLWithPath: databasePath)
        
        measure {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            let realm = try! Realm(fileURL: databaseURL)
            
            try! realm.write {
                for i in 0..<insertedRowCount {
                    realm.add(RealmItem(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i))
                }
            }
        }
    }
    #endif
}
