import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseValueConvertibleDecodableTests: GRDBTestCase {
    func testDatabaseValueConvertibleImplementationDerivedFromDecodable() {
        struct Value : Decodable, DatabaseValueConvertible {
            let string: String
            
            init(from decoder: Decoder) throws {
                string = try decoder.singleValueContainer().decode(String.self)
            }
            
            var databaseValue: DatabaseValue {
                preconditionFailure("unused")
            }
            
            // Infered, tested
            // static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? { ... }
        }
        
        let value = Value.fromDatabaseValue("foo".databaseValue)!
        XCTAssertEqual(value.string, "foo")
    }
    
    func testCustomDatabaseValueConvertible() throws {
        struct Value : Decodable, DatabaseValueConvertible {
            let string: String
            
            var databaseValue: DatabaseValue {
                preconditionFailure("unused")
            }
            
            static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Value? {
                if let string = String.fromDatabaseValue(databaseValue) {
                    return Value(string: string + " (DatabaseValueConvertible)")
                } else {
                    return nil
                }
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let value = try Value.fetchOne(db, "SELECT 'foo'")!
            XCTAssertEqual(value.string, "foo (DatabaseValueConvertible)")
        }
    }
    
    func testDecodableRawRepresentableFetchingMethod() throws {
        enum Value : String, Decodable, DatabaseValueConvertible {
            case foo, bar
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let value = try Value.fetchOne(db, "SELECT 'foo'")!
            XCTAssertEqual(value, .foo)
        }
    }
}
