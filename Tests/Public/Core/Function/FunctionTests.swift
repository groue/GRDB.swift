import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

struct CustomValueType : DatabaseValueConvertible {
    var databaseValue: DatabaseValue {
        return "CustomValueType".databaseValue
    }
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> CustomValueType? {
        guard let string = String.fromDatabaseValue(databaseValue), string == "CustomValueType" else {
            return nil
        }
        return CustomValueType()
    }
}

class FunctionTests: GRDBTestCase {
    
    // MARK: - Default functions
    
    func testDefaultFunctions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
            
                // Those functions are automatically added to all connections.
                // See Database.setupDefaultFunctions()
            
                let capitalize = DatabaseFunction.capitalize
                XCTAssertEqual(try String.fetchOne(db, "SELECT \(capitalize.name)('jérÔME')"), "Jérôme")
                
                let lowercase = DatabaseFunction.lowercase
                XCTAssertEqual(try String.fetchOne(db, "SELECT \(lowercase.name)('jérÔME')"), "jérôme")
                
                let uppercase = DatabaseFunction.uppercase
                XCTAssertEqual(try String.fetchOne(db, "SELECT \(uppercase.name)('jérÔME')"), "JÉRÔME")
                
                if #available(iOS 9.0, OSX 10.11, *) {
                    // Locale-dependent tests. Are they fragile?
                    
                    let localizedCapitalize = DatabaseFunction.localizedCapitalize
                    XCTAssertEqual(try String.fetchOne(db, "SELECT \(localizedCapitalize.name)('jérÔME')"), "Jérôme")
                    
                    let localizedLowercase = DatabaseFunction.localizedLowercase
                    XCTAssertEqual(try String.fetchOne(db, "SELECT \(localizedLowercase.name)('jérÔME')"), "jérôme")
                    
                    let localizedUppercase = DatabaseFunction.localizedUppercase
                    XCTAssertEqual(try String.fetchOne(db, "SELECT \(localizedUppercase.name)('jérÔME')"), "JÉRÔME")
                }
            }
        }
    }
    
    // MARK: - Return values
    
    func testFunctionReturningNull() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return nil
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertTrue(try DatabaseValue.fetchOne(db, "SELECT f()")!.isNull)
            }
        }
    }
    
    func testFunctionReturningInt64() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return Int64(1)
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int64.fetchOne(db, "SELECT f()")!, Int64(1))
            }
        }
    }
    
    func testFunctionReturningDouble() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return 1e100
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Double.fetchOne(db, "SELECT f()")!, 1e100)
            }
        }
    }
    
    func testFunctionReturningString() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return "foo"
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testFunctionReturningData() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return "foo".data(using: .utf8)
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Data.fetchOne(db, "SELECT f()")!, "foo".data(using: .utf8))
            }
        }
    }
    
    func testFunctionReturningCustomValueType() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return CustomValueType()
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT f()") != nil)
            }
        }
    }
    
    // MARK: - Argument values
    
    func testFunctionArgumentNil() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("isNil", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].isNull
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertTrue(try Bool.fetchOne(db, "SELECT isNil(NULL)")!)
                XCTAssertFalse(try Bool.fetchOne(db, "SELECT isNil(1)")!)
                XCTAssertFalse(try Bool.fetchOne(db, "SELECT isNil(1.1)")!)
                XCTAssertFalse(try Bool.fetchOne(db, "SELECT isNil('foo')")!)
                XCTAssertFalse(try Bool.fetchOne(db, "SELECT isNil(?)", arguments: ["foo".data(using: .utf8)])!)
            }
        }
    }
    
    func testFunctionArgumentInt64() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asInt64", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as Int64?
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertTrue(try Int64.fetchOne(db, "SELECT asInt64(NULL)") == nil)
                XCTAssertEqual(try Int64.fetchOne(db, "SELECT asInt64(1)")!, 1)
                XCTAssertEqual(try Int64.fetchOne(db, "SELECT asInt64(1.1)")!, 1)
            }
        }
    }
    
    func testFunctionArgumentDouble() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asDouble", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as Double?
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertTrue(try Double.fetchOne(db, "SELECT asDouble(NULL)") == nil)
                XCTAssertEqual(try Double.fetchOne(db, "SELECT asDouble(1)")!, 1.0)
                XCTAssertEqual(try Double.fetchOne(db, "SELECT asDouble(1.1)")!, 1.1)
            }
        }
    }
    
    func testFunctionArgumentString() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asString", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as String?
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertTrue(try String.fetchOne(db, "SELECT asString(NULL)") == nil)
                XCTAssertEqual(try String.fetchOne(db, "SELECT asString('foo')")!, "foo")
            }
        }
    }
    
    func testFunctionArgumentBlob() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asData", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as Data?
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertTrue(try Data.fetchOne(db, "SELECT asData(NULL)") == nil)
                XCTAssertEqual(try Data.fetchOne(db, "SELECT asData(?)", arguments: ["foo".data(using: .utf8)])!, "foo".data(using: .utf8))
            }
        }
    }
    
    func testFunctionArgumentCustomValueType() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asCustomValueType", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as CustomValueType?
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT asCustomValueType(NULL)") == nil)
                XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT asCustomValueType('CustomValueType')") != nil)
            }
        }
    }
    
    // MARK: - Argument count
    
    func testFunctionWithoutArgument() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return "foo"
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testFunctionOfOneArgument() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("unicodeUpper", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                let dbv = databaseValues[0]
                guard let string: String = dbv.value() else {
                    return nil
                }
                return string.uppercased()
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try String.fetchOne(db, "SELECT upper(?)", arguments: ["Roué"])!, "ROUé")
                XCTAssertEqual(try String.fetchOne(db, "SELECT unicodeUpper(?)", arguments: ["Roué"])!, "ROUÉ")
                XCTAssertTrue(try String.fetchOne(db, "SELECT unicodeUpper(NULL)") == nil)
            }
        }
    }
    
    func testFunctionOfTwoArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 2) { databaseValues in
                let ints: [Int] = databaseValues.flatMap { $0.value() }
                return ints.reduce(0, +)
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT f(1, 2)")!, 3)
            }
        }
    }
    
    func testVariadicFunction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f") { databaseValues in
                return databaseValues.count
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, "SELECT f()")!, 0)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT f(1)")!, 1)
                XCTAssertEqual(try Int.fetchOne(db, "SELECT f(1, 1)")!, 2)
            }
        }
    }
    
    // MARK: - Errors
    
    func testFunctionThrowingDatabaseErrorWithMessage() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw DatabaseError(message: "custom error message")
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "custom error message")
                }
            }
        }
    }
    
    func testFunctionThrowingDatabaseErrorWithCode() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw DatabaseError(resultCode: ResultCode(rawValue: 123))
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode.rawValue, 123)
                    XCTAssertEqual(error.message, "unknown error")
                }
            }
        }
    }
    
    func testFunctionThrowingDatabaseErrorWithMessageAndCode() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw DatabaseError(resultCode: ResultCode(rawValue: 123), message: "custom error message")
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode.rawValue, 123)
                    XCTAssertEqual(error.message, "custom error message")
                }
            }
        }
    }
    
    func testFunctionThrowingCustomError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSString(string: NSLocalizedDescriptionKey): "custom error message"])
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertTrue(error.message!.contains("CustomErrorDomain"))
                    XCTAssertTrue(error.message!.contains("123"))
                    XCTAssertTrue(error.message!.contains("custom error message"))
                }
            }
        }
    }
    
    // MARK: - Misc
    
    func testFunctionsAreClosures() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            var x = 123
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return x
            }
            dbQueue.add(function: fn)
            try dbQueue.inDatabase { db in
                x = 321
                XCTAssertEqual(try Int.fetchOne(db, "SELECT f()")!, 321)
            }
        }
    }
}
