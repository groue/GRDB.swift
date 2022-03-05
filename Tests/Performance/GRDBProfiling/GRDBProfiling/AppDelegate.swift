import Cocoa
import GRDB

let expectedRowCount = 100_000
let insertedRowCount = 20_000

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        try! parseDateComponents()
        try! parseDates()
        try! fetchValues()
        try! fetchPositionalValues()
        try! fetchNamedValues()
        try! fetchStructs()
        try! fetchCodables()
        try! fetchRecords()
        try! insertPositionalValues()
        try! insertNamedValues()
        try! insertStructs()
        try! insertCodables()
        try! insertRecords()
    }
    
    // MARK: -
    
    func parseDateComponents() throws {
        /// Selects many dates
        let request = """
            WITH RECURSIVE
                cnt(x) AS (
                    SELECT 1
                    UNION ALL
                    SELECT x+1 FROM cnt
                    LIMIT 50000
                )
            SELECT '2018-04-20 14:47:12.345' FROM cnt;
            """
        
        try DatabaseQueue().inDatabase { db in
            let cursor = try DatabaseDateComponents.fetchCursor(db, sql: request)
            while try cursor.next() != nil { }
        }
    }
    
    func parseDates() throws {
        /// Selects many dates
        let request = """
            WITH RECURSIVE
                cnt(x) AS (
                    SELECT 1
                    UNION ALL
                    SELECT x+1 FROM cnt
                    LIMIT 50000
                )
            SELECT '2018-04-20 14:47:12.345' FROM cnt;
            """
        
        try DatabaseQueue().inDatabase { db in
            let cursor = try Date.fetchCursor(db, sql: request)
            while try cursor.next() != nil { }
        }
    }
    
    // MARK: -
    
    func fetchValues() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.read(_fetchValues)
    }
    
    func _fetchValues(_ db: Database) throws {
        var count = 0
        
        let cursor = try Int.fetchCursor(db, sql: "SELECT i0 FROM items")
        while try cursor.next() != nil {
            count += 1
        }
        
        assert(count == expectedRowCount)
    }
    
    // MARK: -
    
    func fetchPositionalValues() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.read(_fetchPositionalValues)
    }
    
    func _fetchPositionalValues(_ db: Database) throws {
        var count = 0
        
        let rows = try Row.fetchCursor(db, sql: "SELECT * FROM items")
        while let row = try rows.next() {
            let _: Int = try row[0]
            let _: Int = try row[1]
            let _: Int = try row[2]
            let _: Int = try row[3]
            let _: Int = try row[4]
            let _: Int = try row[5]
            let _: Int = try row[6]
            let _: Int = try row[7]
            let _: Int = try row[8]
            let _: Int = try row[9]
            count += 1
        }
        
        assert(count == expectedRowCount)
    }
    
    // MARK: -
    
    func fetchNamedValues() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.read(_fetchNamedValues)
    }
    
    func _fetchNamedValues(_ db: Database) throws {
        var count = 0
        
        let rows = try Row.fetchCursor(db, sql: "SELECT * FROM items")
        while let row = try rows.next() {
            let _: Int = try row["i0"]
            let _: Int = try row["i1"]
            let _: Int = try row["i2"]
            let _: Int = try row["i3"]
            let _: Int = try row["i4"]
            let _: Int = try row["i5"]
            let _: Int = try row["i6"]
            let _: Int = try row["i7"]
            let _: Int = try row["i8"]
            let _: Int = try row["i9"]
            
            count += 1
        }
        
        assert(count == expectedRowCount)
    }
    
    // MARK: -
    
    func fetchStructs() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        let items = try dbQueue.read(_fetchStructs)
        assert(items.count == expectedRowCount)
        assert(items[0].i0 == 0)
        assert(items[1].i1 == 1)
        assert(items[expectedRowCount-1].i9 == expectedRowCount-1)
    }
    
    func _fetchStructs(_ db: Database) throws -> [ItemStruct] {
        try ItemStruct.fetchAll(db)
    }
    
    // MARK: -
    
    func fetchCodables() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        let items = try dbQueue.read(_fetchCodables)
        assert(items.count == expectedRowCount)
        assert(items[0].i0 == 0)
        assert(items[1].i1 == 1)
        assert(items[expectedRowCount-1].i9 == expectedRowCount-1)
    }
    
    func _fetchCodables(_ db: Database) throws -> [ItemCodable] {
        try ItemCodable.fetchAll(db)
    }

    // MARK: -
    
    func fetchRecords() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "ProfilingDatabase", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        let items = try dbQueue.read(_fetchRecords)
        assert(items.count == expectedRowCount)
        assert(items[0].i0 == 0)
        assert(items[1].i1 == 1)
        assert(items[expectedRowCount-1].i9 == expectedRowCount-1)
    }
    
    func _fetchRecords(_ db: Database) throws -> [ItemRecord] {
        try ItemRecord.fetchAll(db)
    }
    
    // MARK: -
    
    func insertPositionalValues() throws {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        
        let dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        try dbQueue.write(_insertPositionalValues)
        
        try dbQueue.read { db in
            assert(try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")! == insertedRowCount)
            assert(try! Int.fetchOne(db, sql: "SELECT MIN(i0) FROM items")! == 0)
            assert(try! Int.fetchOne(db, sql: "SELECT MAX(i9) FROM items")! == insertedRowCount - 1)
        }
        try FileManager.default.removeItem(atPath: databasePath)
    }
    
    func _insertPositionalValues(_ db: Database) throws {
        let statement = try db.makeStatement(sql: "INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)")
        for i in 0..<insertedRowCount {
            try statement.execute(arguments: [i, i, i, i, i, i, i, i, i, i])
        }
    }
    
    // MARK: -
    
    func insertNamedValues() throws {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        
        let dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        try dbQueue.write(_insertNamedValues)
        
        try dbQueue.read { db in
            assert(try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")! == insertedRowCount)
            assert(try! Int.fetchOne(db, sql: "SELECT MIN(i0) FROM items")! == 0)
            assert(try! Int.fetchOne(db, sql: "SELECT MAX(i9) FROM items")! == insertedRowCount - 1)
        }
        try FileManager.default.removeItem(atPath: databasePath)
    }
    
    func _insertNamedValues(_ db: Database) throws {
        let statement = try db.makeStatement(sql: "INSERT INTO items (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (:i0, :i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9)")
        for i in 0..<insertedRowCount {
            try statement.execute(arguments: ["i0": i, "i1": i, "i2": i, "i3": i, "i4": i, "i5": i, "i6": i, "i7": i, "i8": i, "i9": i])
        }
    }
    
    // MARK: -
    
    func insertStructs() throws {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        
        let dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        try dbQueue.write(_insertStructs)
        
        try dbQueue.read { db in
            assert(try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")! == insertedRowCount)
            assert(try! Int.fetchOne(db, sql: "SELECT MIN(i0) FROM items")! == 0)
            assert(try! Int.fetchOne(db, sql: "SELECT MAX(i9) FROM items")! == insertedRowCount - 1)
        }
        try FileManager.default.removeItem(atPath: databasePath)
    }
    
    func _insertStructs(_ db: Database) throws {
        for i in 0..<insertedRowCount {
            try ItemStruct(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
        }
    }
    
    // MARK: -
    
    func insertCodables() throws {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        
        let dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        try dbQueue.write(_insertCodables)
        
        try dbQueue.read { db in
            assert(try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")! == insertedRowCount)
            assert(try! Int.fetchOne(db, sql: "SELECT MIN(i0) FROM items")! == 0)
            assert(try! Int.fetchOne(db, sql: "SELECT MAX(i9) FROM items")! == insertedRowCount - 1)
        }
        try FileManager.default.removeItem(atPath: databasePath)
    }
    
    func _insertCodables(_ db: Database) throws {
        for i in 0..<insertedRowCount {
            try ItemCodable(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
        }
    }

    // MARK: -
    
    func insertRecords() throws {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        
        let dbQueue = try DatabaseQueue(path: databasePath)
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE items (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        }
        
        try dbQueue.write(_insertRecords)
        
        try dbQueue.read { db in
            assert(try! Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")! == insertedRowCount)
            assert(try! Int.fetchOne(db, sql: "SELECT MIN(i0) FROM items")! == 0)
            assert(try! Int.fetchOne(db, sql: "SELECT MAX(i9) FROM items")! == insertedRowCount - 1)
        }
        try FileManager.default.removeItem(atPath: databasePath)
    }
    
    func _insertRecords(_ db: Database) throws {
        for i in 0..<insertedRowCount {
            try ItemRecord(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i).insert(db)
        }
    }
}

class ItemRecord : Record {
    var i0: Int?
    var i1: Int?
    var i2: Int?
    var i3: Int?
    var i4: Int?
    var i5: Int?
    var i6: Int?
    var i7: Int?
    var i8: Int?
    var i9: Int?
    
    init(i0: Int?, i1: Int?, i2: Int?, i3: Int?, i4: Int?, i5: Int?, i6: Int?, i7: Int?, i8: Int?, i9: Int?) {
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
    
    override class var databaseTableName: String {
        "items"
    }
    
    required init(row: GRDB.Row) throws {
        i0 = try row["i0"]
        i1 = try row["i1"]
        i2 = try row["i2"]
        i3 = try row["i3"]
        i4 = try row["i4"]
        i5 = try row["i5"]
        i6 = try row["i6"]
        i7 = try row["i7"]
        i8 = try row["i8"]
        i9 = try row["i9"]
        try super.init(row: row)
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

struct ItemStruct: FetchableRecord, PersistableRecord {
    var i0: Int?
    var i1: Int?
    var i2: Int?
    var i3: Int?
    var i4: Int?
    var i5: Int?
    var i6: Int?
    var i7: Int?
    var i8: Int?
    var i9: Int?
    
    init(i0: Int?, i1: Int?, i2: Int?, i3: Int?, i4: Int?, i5: Int?, i6: Int?, i7: Int?, i8: Int?, i9: Int?) {
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
    }
    
    static let databaseTableName = "items"
    
    init(row: GRDB.Row) throws {
        i0 = try row["i0"]
        i1 = try row["i1"]
        i2 = try row["i2"]
        i3 = try row["i3"]
        i4 = try row["i4"]
        i5 = try row["i5"]
        i6 = try row["i6"]
        i7 = try row["i7"]
        i8 = try row["i8"]
        i9 = try row["i9"]
    }
    
    func encode(to container: inout PersistenceContainer) {
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

struct ItemCodable : Codable, FetchableRecord, PersistableRecord {
    var i0: Int?
    var i1: Int?
    var i2: Int?
    var i3: Int?
    var i4: Int?
    var i5: Int?
    var i6: Int?
    var i7: Int?
    var i8: Int?
    var i9: Int?
    
    static let databaseTableName = "items"
}
