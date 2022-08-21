import XCTest
@testable import GRDB

class DatabaseValueConversionErrorTests: GRDBTestCase {
    func testFetchableRecord1() throws {
        struct Record: FetchableRecord {
            var name: String

            init(row: Row) throws {
                name = try row.decode(forKey: "name")
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT ? AS name")
            statement.arguments = [nil]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode String from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil])
                    XCTAssertEqual(context.sql, "SELECT ? AS name")
                    XCTAssertEqual(context.statementArguments, [nil])
                    XCTAssertEqual(error.description, """
                        could not decode String from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL], \
                        sql: `SELECT ? AS name`, \
                        arguments: [NULL]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("name"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        column not found: "name" - \
                        row: [unused:"ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("name"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, "SELECT ? AS unused")
                    XCTAssertEqual(context.statementArguments, ["ignored"])
                    XCTAssertEqual(error.description, """
                        column not found: "name" - \
                        row: [unused:"ignored"], \
                        sql: `SELECT ? AS unused`, \
                        arguments: ["ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
    
    func testFetchableRecord2() throws {
        enum Value: String, DatabaseValueConvertible {
            case valid
        }
        
        struct Record: FetchableRecord {
            var value: Value

            init(row: Row) throws {
                value = try row.decode(forKey: "value")
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT 1, ? AS value")
            statement.arguments = ["invalid"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(1))
                    XCTAssertEqual(context.row, ["1": 1, "value": "invalid"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value "invalid" - \
                        column: "value", \
                        column index: 1, \
                        row: [1:1 value:"invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(1))
                    XCTAssertEqual(context.row, ["1": 1, "value": "invalid"])
                    XCTAssertEqual(context.sql, "SELECT 1, ? AS value")
                    XCTAssertEqual(context.statementArguments, ["invalid"])
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value "invalid" - \
                        column: "value", \
                        column index: 1, \
                        row: [1:1 value:"invalid"], \
                        sql: `SELECT 1, ? AS value`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("value"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        column not found: "value" - \
                        row: [unused:"ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("value"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, "SELECT ? AS unused")
                    XCTAssertEqual(context.statementArguments, ["ignored"])
                    XCTAssertEqual(error.description, """
                        column not found: "value" - \
                        row: [unused:"ignored"], \
                        sql: `SELECT ? AS unused`, \
                        arguments: ["ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
    
    func testDecodableFetchableRecord1() throws {
        struct Record: Decodable, FetchableRecord {
            var name: String
            var team: String
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode String from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, "SELECT NULL AS name, ? AS team")
                    XCTAssertEqual(context.statementArguments, ["invalid"])
                    XCTAssertEqual(error.description, """
                        could not decode String from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"], \
                        sql: `SELECT NULL AS name, ? AS team`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("name"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        column not found: "name" - \
                        row: [unused:"ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("name"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, "SELECT ? AS unused")
                    XCTAssertEqual(context.statementArguments, ["ignored"])
                    XCTAssertEqual(error.description, """
                        column not found: "name" - \
                        row: [unused:"ignored"], \
                        sql: `SELECT ? AS unused`, \
                        arguments: ["ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
    
    func testDecodableFetchableRecord2() throws {
        enum Value: String, DatabaseValueConvertible, Decodable {
            case valid
        }
        
        struct Record: Decodable, FetchableRecord {
            var value: Value
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT NULL AS name, ? AS value")
            statement.arguments = ["invalid"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(1))
                    XCTAssertEqual(context.row, ["name": nil, "value": "invalid"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value "invalid" - \
                        column: "value", \
                        column index: 1, \
                        row: [name:NULL value:"invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(1))
                    XCTAssertEqual(context.row, ["name": nil, "value": "invalid"])
                    XCTAssertEqual(context.sql, "SELECT NULL AS name, ? AS value")
                    XCTAssertEqual(context.statementArguments, ["invalid"])
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value "invalid" - \
                        column: "value", \
                        column index: 1, \
                        row: [name:NULL value:"invalid"], \
                        sql: `SELECT NULL AS name, ? AS value`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("value"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        column not found: "value" - \
                        row: [unused:"ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("value"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, "SELECT ? AS unused")
                    XCTAssertEqual(context.statementArguments, ["ignored"])
                    XCTAssertEqual(error.description, """
                        column not found: "value" - \
                        row: [unused:"ignored"], \
                        sql: `SELECT ? AS unused`, \
                        arguments: ["ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
    
    func testDecodableFetchableRecord3() throws {
        enum Value: String, Decodable {
            case valid
        }
        
        struct Record: Decodable, FetchableRecord {
            var value: Value
        }
        
        let dbQueue = try makeDatabaseQueue()
        
        // conversion error
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT NULL AS name, ? AS value")
            statement.arguments = ["invalid"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as DecodingError {
                switch error {
                case .dataCorrupted:
                    break
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, "SELECT NULL AS name, ? AS team")
                    XCTAssertEqual(context.statementArguments, ["invalid"])
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"], \
                        sql: `SELECT NULL AS name, ? AS team`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            } catch let error as DecodingError {
                switch error {
                case .dataCorrupted:
                    break
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
        
        // missing column
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT ? AS unused")
            statement.arguments = ["ignored"]
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try Record(row: row)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("value"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        column not found: "value" - \
                        row: [unused:"ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Record.fetchOne(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("value"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["unused": "ignored"])
                    XCTAssertEqual(context.sql, "SELECT ? AS unused")
                    XCTAssertEqual(context.statementArguments, ["ignored"])
                    XCTAssertEqual(error.description, """
                        column not found: "value" - \
                        row: [unused:"ignored"], \
                        sql: `SELECT ? AS unused`, \
                        arguments: ["ignored"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
    
    func testStatementColumnConvertible1() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            
            do {
                _ = try String.fetchAll(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, "SELECT NULL AS name, ? AS team")
                    XCTAssertEqual(context.statementArguments, ["invalid"])
                    XCTAssertEqual(error.description, """
                        could not decode String from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"], \
                        sql: `SELECT NULL AS name, ? AS team`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try row.decode(String.self, forKey: "name")
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode String from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try row.decode(String.self, atIndex: 0)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode String from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
    
    func testStatementColumnConvertible2() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT ? AS foo")
            statement.arguments = [1000]
            
            do {
                _ = try Row.fetchCursor(statement)
                    .map { try $0.decode(Int8.self, forKey: "missing") }
                    .next()
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    XCTAssertEqual(key, .columnName("missing"))
                    XCTAssertEqual(context.key, nil)
                    XCTAssertEqual(context.row, ["foo": 1000])
                    XCTAssertEqual(context.sql, "SELECT ? AS foo")
                    XCTAssertEqual(context.statementArguments, [1000])
                    XCTAssertEqual(error.description, """
                        column not found: "missing" - \
                        row: [foo:1000], \
                        sql: `SELECT ? AS foo`, \
                        arguments: [1000]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Int8.fetchAll(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["foo": 1000])
                    XCTAssertEqual(context.sql, "SELECT ? AS foo")
                    XCTAssertEqual(context.statementArguments, [1000])
                    XCTAssertEqual(error.description, """
                        could not decode Int8 from database value 1000 - \
                        column: "foo", \
                        column index: 0, \
                        row: [foo:1000], \
                        sql: `SELECT ? AS foo`, \
                        arguments: [1000]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try row.decode(Int8.self, forKey: "foo")
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["foo": 1000])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode Int8 from database value 1000 - \
                        column: "foo", \
                        column index: 0, \
                        row: [foo:1000]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try row.decode(Int8.self, atIndex: 0)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["foo": 1000])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode Int8 from database value 1000 - \
                        column: "foo", \
                        column index: 0, \
                        row: [foo:1000]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
    
    func testDecodableDatabaseValueConvertible() throws {
        enum Value: String, DatabaseValueConvertible, Decodable {
            case valid
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let statement = try db.makeStatement(sql: "SELECT NULL AS name, ? AS team")
            statement.arguments = ["invalid"]
            
            do {
                _ = try Value.fetchAll(statement)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, "SELECT NULL AS name, ? AS team")
                    XCTAssertEqual(context.statementArguments, ["invalid"])
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"], \
                        sql: `SELECT NULL AS name, ? AS team`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                _ = try Value.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(1))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, "SELECT NULL AS name, ? AS team")
                    XCTAssertEqual(context.statementArguments, ["invalid"])
                    XCTAssertEqual(error.description, """
                        could not decode \(Optional<Value>.self) from database value "invalid" - \
                        column: "team", \
                        column index: 1, \
                        row: [name:NULL team:"invalid"], \
                        sql: `SELECT NULL AS name, ? AS team`, \
                        arguments: ["invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try row.decode(Value.self, forKey: "name")
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                let row = try Row.fetchOne(statement)!
                _ = try row.decode(Value.self, atIndex: 0)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["name": nil, "team": "invalid"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value NULL - \
                        column: "name", \
                        column index: 0, \
                        row: [name:NULL team:"invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
            
            do {
                let row = try Row.fetchOne(statement, adapter: SuffixRowAdapter(fromIndex: 1))!
                _ = try row.decode(Value.self, atIndex: 0)
                XCTFail("Expected error")
            } catch let error as RowDecodingError {
                switch error {
                case let .valueMismatch(_, context):
                    XCTAssertEqual(context.key, .columnIndex(0))
                    XCTAssertEqual(context.row, ["team": "invalid"])
                    XCTAssertEqual(context.sql, nil)
                    XCTAssertEqual(context.statementArguments, nil)
                    XCTAssertEqual(error.description, """
                        could not decode \(Value.self) from database value "invalid" - \
                        column: "team", \
                        column index: 0, \
                        row: [team:"invalid"]
                        """)
                default:
                    XCTFail("Unexpected Error")
                }
            }
        }
    }
}
