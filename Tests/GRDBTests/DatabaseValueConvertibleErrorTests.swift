import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseValueConvertibleErrorTests: GRDBTestCase {
    struct Record1: Codable, FetchableRecord {
        var name: String
        var team: String
    }
    
    struct Record2: FetchableRecord {
        var name: String
        var team: String
        
        init(row: Row) {
            name = row["name"]
            team = row["team"]
        }
    }
    
    struct Record3: Codable, FetchableRecord {
        var team: Value1
    }
    
    struct Record4: FetchableRecord {
        var team: Value1
        
        init(row: Row) {
            team = row["team"]
        }
    }
    
    enum Value1: String, DatabaseValueConvertible, Codable {
        case valid
    }
    
    func testError() throws {
        // TODO: find a way to turn those into real tests
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
//            let statement = try db.makeSelectStatement("SELECT NULL AS name, ? AS team")
//            statement.arguments = ["invalid"]
//            let row = try Row.fetchOne(statement)!
//
//            // could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:"invalid"])
//            _ = Record1(row: row)
//            
//            // could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:"foo"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["foo"])
//            _ = try Record1.fetchOne(statement)
//            
//            // could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:"foo"])
//            _ = Record2(row: row)
//            
//            // could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:"foo"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["foo"])
//            _ = try Record2.fetchOne(statement)
//            
//            // could not convert database value "foo" to Value1 (column: `team`, column index: 1, row: [name:NULL team:"foo"])
//            _ = Record3(row: row)
//
//            // could not convert database value "foo" to Value1 (column: `team`, column index: 1, row: [name:NULL team:"foo"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["foo"])
//            _ = try Record3.fetchOne(statement)
//
//            // could not convert database value "foo" to Value1 (column: `team`, column index: 1, row: [name:NULL team:"foo"])
//            _ = Record4(row: row)
//
//            // could not convert database value "foo" to Value1 (column: `team`, column index: 1, row: [name:NULL team:"foo"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["foo"])
//            _ = try Record4.fetchOne(statement)
//
//            // could not convert database value NULL to String (column index: 0, row: [name:NULL team:"foo"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["foo"])
//            _ = try String.fetchAll(statement)
//            
//            // could not convert database value NULL to String (column: `name`, column index: 0, row: [name:NULL team:"foo"])
//            _ = row["name"] as String
//            
//            // could not convert database value NULL to String (column index: 0, row: [name:NULL team:"foo"])
//            _ = row[0] as String
//            
//            // could not convert database value NULL to Value1 (column index: 0, row: [name:NULL team:"foo"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["foo"])
//            _ = try Value1.fetchAll(statement)
//            
//            // could not convert database value "foo" to Value1 (column: `team`, column index: 1, row: [name:NULL team:"foo"], statement: `SELECT NULL AS name, ? AS team`, arguments: ["foo"])
//            _ = try Value1.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
//
//            // could not convert database value NULL to Value1 (column: `name`, column index: 0, row: [name:NULL team:"foo"])
//            _ = row["name"] as Value1
//
//            // could not convert database value NULL to Value1 (index: 0, row: [name:NULL team:"foo"])
//            _ = row[0] as Value1
        }
    }
}
