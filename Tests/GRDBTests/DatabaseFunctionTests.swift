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

class DatabaseFunctionTests: GRDBTestCase {
    
    // MARK: - Default functions
    
    func testDefaultFunctions() throws {
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

    // MARK: - Return values

    func testFunctionReturningNull() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
            return nil
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try DatabaseValue.fetchOne(db, "SELECT f()")!.isNull)
        }
    }

    func testFunctionReturningInt64() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
            return Int64(1)
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Int64.fetchOne(db, "SELECT f()")!, Int64(1))
        }
    }

    func testFunctionReturningDouble() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
            return 1e100
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Double.fetchOne(db, "SELECT f()")!, 1e100)
        }
    }

    func testFunctionReturningString() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
            return "foo"
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try String.fetchOne(db, "SELECT f()")!, "foo")
        }
    }

    func testFunctionReturningData() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
            return "foo".data(using: .utf8)
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Data.fetchOne(db, "SELECT f()")!, "foo".data(using: .utf8))
        }
    }

    func testFunctionReturningCustomValueType() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
            return CustomValueType()
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT f()") != nil)
        }
    }

    // MARK: - Argument values
    
    func testFunctionArgumentNil() throws {
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

    func testFunctionArgumentInt64() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("asInt64", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
            return Int64.fromDatabaseValue(databaseValues[0])
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try Int64.fetchOne(db, "SELECT asInt64(NULL)") == nil)
            XCTAssertEqual(try Int64.fetchOne(db, "SELECT asInt64(1)")!, 1)
            XCTAssertEqual(try Int64.fetchOne(db, "SELECT asInt64(1.1)")!, 1)
        }
    }

    func testFunctionArgumentDouble() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("asDouble", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
            return Double.fromDatabaseValue(databaseValues[0])
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try Double.fetchOne(db, "SELECT asDouble(NULL)") == nil)
            XCTAssertEqual(try Double.fetchOne(db, "SELECT asDouble(1)")!, 1.0)
            XCTAssertEqual(try Double.fetchOne(db, "SELECT asDouble(1.1)")!, 1.1)
        }
    }

    func testFunctionArgumentString() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("asString", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
            return String.fromDatabaseValue(databaseValues[0])
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try String.fetchOne(db, "SELECT asString(NULL)") == nil)
            XCTAssertEqual(try String.fetchOne(db, "SELECT asString('foo')")!, "foo")
        }
    }

    func testFunctionArgumentBlob() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("asData", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
            return Data.fromDatabaseValue(databaseValues[0])
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try Data.fetchOne(db, "SELECT asData(NULL)") == nil)
            XCTAssertEqual(try Data.fetchOne(db, "SELECT asData(?)", arguments: ["foo".data(using: .utf8)])!, "foo".data(using: .utf8))
        }
    }

    func testFunctionArgumentCustomValueType() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("asCustomValueType", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
            return CustomValueType.fromDatabaseValue(databaseValues[0])
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT asCustomValueType(NULL)") == nil)
            XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT asCustomValueType('CustomValueType')") != nil)
        }
    }

    // MARK: - Argument count
    
    func testFunctionWithoutArgument() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
            return "foo"
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try String.fetchOne(db, "SELECT f()")!, "foo")
        }
    }

    func testFunctionOfOneArgument() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("unicodeUpper", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
            let dbv = databaseValues[0]
            guard let string = String.fromDatabaseValue(dbv) else {
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

    func testFunctionOfTwoArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 2) { databaseValues in
            let ints = databaseValues.flatMap { Int.fromDatabaseValue($0) }
            return ints.reduce(0, +)
        }
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Int.fetchOne(db, "SELECT f(1, 2)")!, 3)
        }
    }

    func testVariadicFunction() throws {
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

    // MARK: - Errors

    func testFunctionThrowingDatabaseErrorWithMessage() throws {
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

    func testFunctionThrowingDatabaseErrorWithCode() throws {
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

    func testFunctionThrowingDatabaseErrorWithMessageAndCode() throws {
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

    func testFunctionThrowingCustomError() throws {
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
            throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "custom error message"])
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

    // MARK: - Misc

    func testFunctionsAreClosures() throws {
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
