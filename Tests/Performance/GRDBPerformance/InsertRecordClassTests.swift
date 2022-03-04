import XCTest
import GRDB
#if GRDB_COMPARE
import CoreData
import RealmSwift
#endif

private let insertedRowCount = 50_000

// Here we insert record classes.
class InsertRecordClassTests: XCTestCase {
    
    func testGRDB() {
        class Item: Record {
            var i0: Int
            var i1: Int
            var i2: Int
            var i3: Int
            var i4: Int
            var i5: Int
            var i6: Int
            var i7: Int
            var i8: Int
            var i9: Int
            
            override class var databaseTableName: String {
                "item"
            }
            
            init(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int) {
                self.i0 = i0
                self.i1 = i1
                self.i2 = i2
                self.i3 = i3
                self.i4 = i4
                self.i5 = i5
                self.i6 = i6
                self.i7 = i7
                self.i8 = i8
                self.i9 = i9
                super.init()
            }
            
            required init(row: Row) throws {
                fatalError("init(row:) has not been implemented")
            }
            
            override func encode(to container: inout PersistenceContainer) {
                container["i0"] = i0
                container["i1"] = i1
                container["i2"] = i2
                container["i3"] = i3
                container["i4"] = i4
                container["i5"] = i5
                container["i6"] = i6
                container["i7"] = i7
                container["i8"] = i8
                container["i9"] = i9
            }
        }
        
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item")!, insertedRowCount)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT MIN(i0) FROM item")!, 0)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT MAX(i9) FROM item")!, insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        measure {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE item (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            try! dbQueue.inTransaction { db in
                for i in 0..<insertedRowCount {
                    try Item(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
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
