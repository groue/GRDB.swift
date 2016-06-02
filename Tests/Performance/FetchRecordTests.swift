import XCTest
import GRDB
import SQLite
import CoreData
import RealmSwift

private let expectedRowCount = 100_000

/// Here we test the extraction of models from rows
class FetchRecordTests: XCTestCase {

    func testSQLite() {
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        var connection: OpaquePointer = nil
        sqlite3_open_v2(databasePath, &connection, 0x00000004 /*SQLITE_OPEN_CREATE*/ | 0x00000002 /*SQLITE_OPEN_READWRITE*/, nil)
        
        self.measureBlock {
            var statement: OpaquePointer = nil
            sqlite3_prepare_v2(connection, "SELECT * FROM items", -1, &statement, nil)
            
            let columnNames = (Int32(0)..<10).map { String(cString: sqlite3_column_name(statement, $0))! }
            let index0 = Int32(columnNames.indexOf("i0")!)
            let index1 = Int32(columnNames.indexOf("i1")!)
            let index2 = Int32(columnNames.indexOf("i2")!)
            let index3 = Int32(columnNames.indexOf("i3")!)
            let index4 = Int32(columnNames.indexOf("i4")!)
            let index5 = Int32(columnNames.indexOf("i5")!)
            let index6 = Int32(columnNames.indexOf("i6")!)
            let index7 = Int32(columnNames.indexOf("i7")!)
            let index8 = Int32(columnNames.indexOf("i8")!)
            let index9 = Int32(columnNames.indexOf("i9")!)
            
            var items = [Item]()
            loop: while true {
                switch sqlite3_step(statement) {
                case 101 /*SQLITE_DONE*/:
                    break loop
                case 100 /*SQLITE_ROW*/:
                    let item = Item(
                        i0: Int(sqlite3_column_int64(statement, index0)),
                        i1: Int(sqlite3_column_int64(statement, index1)),
                        i2: Int(sqlite3_column_int64(statement, index2)),
                        i3: Int(sqlite3_column_int64(statement, index3)),
                        i4: Int(sqlite3_column_int64(statement, index4)),
                        i5: Int(sqlite3_column_int64(statement, index5)),
                        i6: Int(sqlite3_column_int64(statement, index6)),
                        i7: Int(sqlite3_column_int64(statement, index7)),
                        i8: Int(sqlite3_column_int64(statement, index8)),
                        i9: Int(sqlite3_column_int64(statement, index9)))
                    items.append(item)
                    break
                default:
                    XCTFail()
                }
            }
            
            sqlite3_finalize(statement)
            
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
        
        sqlite3_close(connection)
    }
    
    func testFMDB() {
        // Here we test the loading of an array of Records.
        
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var items = [Item]()
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let item = Item(dictionary: rs.resultDictionary())
                        items.append(item)
                    }
                }
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }

    func testGRDB() {
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        measureBlock {
            let items = dbQueue.inDatabase { db in
                Item.fetchAll(db, "SELECT * FROM items")
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }

    func testSQLiteSwift() {
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let db = try! Connection(databasePath)
        
        self.measureBlock {
            var items = [Item]()
            for row in try! db.prepare(itemsTable) {
                let item = Item(
                    i0: row[i0Column],
                    i1: row[i1Column],
                    i2: row[i2Column],
                    i3: row[i3Column],
                    i4: row[i4Column],
                    i5: row[i5Column],
                    i6: row[i6Column],
                    i7: row[i7Column],
                    i8: row[i8Column],
                    i9: row[i9Column])
                items.append(item)
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }
    
    func testCoreData() {
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceCoreDataTests", ofType: "sqlite")!
        let modelURL = NSBundle(for: self.dynamicType).URLForResource("PerformanceModel", withExtension: "momd")!
        let mom = NSManagedObjectModel(contentsOfURL: modelURL)!
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        try! psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: NSURL(fileURLWithPath: databasePath), options: nil)
        let moc = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        moc.persistentStoreCoordinator = psc
        
        measureBlock {
            let request = NSFetchRequest(entityName: "Item")
            let items = try! moc.executeFetchRequest(request)
            for item in items {
                item.valueForKey("i0")
                item.valueForKey("i1")
                item.valueForKey("i2")
                item.valueForKey("i3")
                item.valueForKey("i4")
                item.valueForKey("i5")
                item.valueForKey("i6")
                item.valueForKey("i7")
                item.valueForKey("i8")
                item.valueForKey("i9")
            }
            XCTAssertEqual(items.count, expectedRowCount)
        }
    }
    
    func testRealm() {
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceRealmTests", ofType: "realm")!
        let realm = try! Realm(path: databasePath)
        
        measureBlock {
            let items = realm.objects(RealmItem)
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
}
