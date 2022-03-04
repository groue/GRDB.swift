import XCTest
import GRDB

// Tests about how minimal can class go regarding their initializers

// What happens for a class without property, without any initializer?
class EmptyRecordWithoutInitializer : Record {
    // nothing is required
}

// What happens if we add a mutable property, still without any initializer?
// A compiler error: class 'RecordWithoutInitializer' has no initializers
//
//    class RecordWithoutInitializer : Record {
//        let name: String?
//    }

// What happens with a mutable property, and init(row: Row)?
class RecordWithMutablePropertyAndRowInitializer : Record {
    var name: String?
    
    required init(row: Row) throws {
        try super.init(row: row)     // super.init(row: row) is required
        self.name = "toto"           // property can be set before or after super.init
    }
}

// What happens with a mutable property, and init()?
class RecordWithMutablePropertyAndEmptyInitializer : Record {
    var name: String?
    
    override init() {
        super.init()                 // super.init() is required
        self.name = "toto"           // property can be set before or after super.init
    }
    
    required init(row: Row) throws { // init(row) is required
        try super.init(row: row)     // super.init(row: row) is required
    }
}

// What happens with a mutable property, and a custom initializer()?
class RecordWithMutablePropertyAndCustomInitializer : Record {
    var name: String?
    
    init(name: String? = nil) {
        self.name = name
        super.init()                 // super.init() is required
    }

    required init(row: Row) throws { // init(row) is required
        try super.init(row: row)     // super.init(row: row) is required
    }
}

// What happens with an immutable property?
class RecordWithImmutableProperty : Record {
    let initializedFromRow: Bool
    
    required init(row: Row) throws { // An initializer is required, and the minimum is init(row)
        initializedFromRow = true    // property must be set before super.init(row: row)
        try super.init(row: row)     // super.init(row: row) is required
    }
}

// What happens with an immutable property and init()?
class RecordWithPedigree : Record {
    let initializedFromRow: Bool
    
    override init() {
        initializedFromRow = false   // property must be set before super.init(row: row)
        super.init()                 // super.init() is required
    }
    
    required init(row: Row) throws { // An initializer is required, and the minimum is init(row)
        initializedFromRow = true    // property must be set before super.init(row: row)
        try super.init(row: row)     // super.init(row: row) is required
    }
}

// What happens with an immutable property and a custom initializer()?
class RecordWithImmutablePropertyAndCustomInitializer : Record {
    let initializedFromRow: Bool
    
    init(name: String? = nil) {
        initializedFromRow = false   // property must be set before super.init(row: row)
        super.init()                 // super.init() is required
    }
    
    required init(row: Row) throws { // An initializer is required, and the minimum is init(row)
        initializedFromRow = true    // property must be set before super.init(row: row)
        try super.init(row: row)     // super.init(row: row) is required
    }
}

class RecordInitializersTests : GRDBTestCase {
    
    func testFetchedRecordAreInitializedFromRow() throws {
        
        // Here we test that Record.init(row: Row) can be overridden independently from Record.init().
        // People must be able to perform some initialization work when fetching records from the database.
        
        XCTAssertFalse(RecordWithPedigree().initializedFromRow)
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE pedigrees (foo INTEGER)")
            try db.execute(sql: "INSERT INTO pedigrees (foo) VALUES (NULL)")
            
            let pedigree = try RecordWithPedigree.fetchOne(db, sql: "SELECT * FROM pedigrees")!
            XCTAssertTrue(pedigree.initializedFromRow)  // very important
        }
    }
}
