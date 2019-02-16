import XCTest
import SQLite3
import GRDB
#if GRDB_COMPARE
import CoreData
import RealmSwift
#endif

private let expectedRowCount = 100_000

/// Here we test the extraction of models from rows
class FetchRecordClassTests: XCTestCase {

    func testGRDB() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        
        measure {
            let items = try! dbQueue.inDatabase { db in
                try ItemClass.fetchAll(db, sql: "SELECT * FROM items")
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }
    
    #if GRDB_COMPARE
    func testCoreData() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceCoreDataTests", ofType: "sqlite")!
        let modelURL = Bundle(for: type(of: self)).url(forResource: "PerformanceModel", withExtension: "momd")!
        let mom = NSManagedObjectModel(contentsOf: modelURL)!
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: URL(fileURLWithPath: databasePath), options: nil)
        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.persistentStoreCoordinator = psc
        
        measure {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
            let items = try! moc.fetch(request)
            for item in items {
                let item = item as AnyObject
                _ = item.value(forKey: "i0")
                _ = item.value(forKey: "i1")
                _ = item.value(forKey: "i2")
                _ = item.value(forKey: "i3")
                _ = item.value(forKey: "i4")
                _ = item.value(forKey: "i5")
                _ = item.value(forKey: "i6")
                _ = item.value(forKey: "i7")
                _ = item.value(forKey: "i8")
                _ = item.value(forKey: "i9")
            }
            XCTAssertEqual(items.count, expectedRowCount)
        }
    }
    
    func testRealm() throws {
        let databaseURL = Bundle(for: type(of: self)).url(forResource: "PerformanceRealmTests", withExtension: "realm")!
        let realm = try Realm(fileURL: databaseURL)
        
        measure {
            let items = realm.objects(RealmItem.self)
            var count = 0
            for item in items {
                count += 1
                _ = item.i0
                _ = item.i1
                _ = item.i2
                _ = item.i3
                _ = item.i4
                _ = item.i5
                _ = item.i6
                _ = item.i7
                _ = item.i8
                _ = item.i9
            }
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    #endif
}
