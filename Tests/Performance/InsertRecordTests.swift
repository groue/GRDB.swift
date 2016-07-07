import XCTest
import GRDB
import CoreData
import RealmSwift

private let insertedRowCount = 20_000

// Here we insert records.
class InsertRecordTests: XCTestCase {
    
    func testGRDB() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, insertedRowCount)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MIN(i0) FROM items")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT MAX(i9) FROM items")!, insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        measureBlock {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            try! dbQueue.inTransaction { db in
                for i in 0..<insertedRowCount {
                    try Item(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
                }
                return .commit
            }
        }
    }
    
    func testCoreData() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        let modelURL = NSBundle(for: self.dynamicType).URLForResource("PerformanceModel", withExtension: "momd")!
        let mom = NSManagedObjectModel(contentsOfURL: modelURL)!
        
        measureBlock {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
            let store = try! psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: NSURL(fileURLWithPath: databasePath), options: nil)
            let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
            moc.persistentStoreCoordinator = psc
            
            for i in 0..<insertedRowCount {
                let item = NSEntityDescription.insertNewObjectForEntityForName("Item", inManagedObjectContext: moc)
                item.setValue(NSNumber(integer: i), forKey: "i0")
                item.setValue(NSNumber(integer: i), forKey: "i1")
                item.setValue(NSNumber(integer: i), forKey: "i2")
                item.setValue(NSNumber(integer: i), forKey: "i3")
                item.setValue(NSNumber(integer: i), forKey: "i4")
                item.setValue(NSNumber(integer: i), forKey: "i5")
                item.setValue(NSNumber(integer: i), forKey: "i6")
                item.setValue(NSNumber(integer: i), forKey: "i7")
                item.setValue(NSNumber(integer: i), forKey: "i8")
                item.setValue(NSNumber(integer: i), forKey: "i9")
            }
            try! moc.save()
            try! psc.removePersistentStore(store)
            try! FileManager.default.removeItem(atPath: databasePath)
        }
    }
    
    func testRealm() {
        let databaseFileName = "GRDBPerformanceTests-\(NSProcessInfo.processInfo.globallyUniqueString).realm"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        
        measureBlock {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            let realm = try! Realm(path: databasePath)
            
            try! realm.write {
                for i in 0..<insertedRowCount {
                    realm.add(RealmItem(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i))
                }
            }
        }
    }
}
