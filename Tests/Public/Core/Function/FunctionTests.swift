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
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> CustomValueType? {
        guard let string = String.fromDatabaseValue(databaseValue) where string == "CustomValueType" else {
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
            dbQueue.inDatabase { db in
            
                // Those functions are automatically added to all connections.
                // See Database.setupDefaultFunctions()
            
                let capitalizedString = DatabaseFunction.capitalizedString
                XCTAssertEqual(String.fetchOne(db, "SELECT \(capitalizedString.name)('jérÔME')"), "Jérôme")
                
                let lowercaseString = DatabaseFunction.lowercaseString
                XCTAssertEqual(String.fetchOne(db, "SELECT \(lowercaseString.name)('jérÔME')"), "jérôme")
                
                let uppercaseString = DatabaseFunction.uppercaseString
                XCTAssertEqual(String.fetchOne(db, "SELECT \(uppercaseString.name)('jérÔME')"), "JÉRÔME")
                
                if #available(iOS 9.0, OSX 10.11, *) {
                    // Locale-dependent tests. Are they fragile?
                    
                    let localizedCapitalizedString = DatabaseFunction.localizedCapitalizedString
                    XCTAssertEqual(String.fetchOne(db, "SELECT \(localizedCapitalizedString.name)('jérÔME')"), "Jérôme")
                    
                    let localizedLowercaseString = DatabaseFunction.localizedLowercaseString
                    XCTAssertEqual(String.fetchOne(db, "SELECT \(localizedLowercaseString.name)('jérÔME')"), "jérôme")
                    
                    let localizedUppercaseString = DatabaseFunction.localizedUppercaseString
                    XCTAssertEqual(String.fetchOne(db, "SELECT \(localizedUppercaseString.name)('jérÔME')"), "JÉRÔME")
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
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(DatabaseValue.fetchOne(db, "SELECT f()") == nil)
            }
        }
    }
    
    func testFunctionReturningInt64() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return Int64(1)
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int64.fetchOne(db, "SELECT f()")!, Int64(1))
            }
        }
    }
    
    func testFunctionReturningDouble() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return 1e100
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Double.fetchOne(db, "SELECT f()")!, 1e100)
            }
        }
    }
    
    func testFunctionReturningString() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return "foo"
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testFunctionReturningData() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return "foo".dataUsingEncoding(NSUTF8StringEncoding)
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(NSData.fetchOne(db, "SELECT f()")!, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testFunctionReturningCustomValueType() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return CustomValueType()
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT f()") != nil)
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
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(Bool.fetchOne(db, "SELECT isNil(NULL)")!)
                XCTAssertFalse(Bool.fetchOne(db, "SELECT isNil(1)")!)
                XCTAssertFalse(Bool.fetchOne(db, "SELECT isNil(1.1)")!)
                XCTAssertFalse(Bool.fetchOne(db, "SELECT isNil('foo')")!)
                XCTAssertFalse(Bool.fetchOne(db, "SELECT isNil(?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)])!)
            }
        }
    }
    
    func testFunctionArgumentInt64() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asInt64", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as Int64?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(Int64.fetchOne(db, "SELECT asInt64(NULL)") == nil)
                XCTAssertEqual(Int64.fetchOne(db, "SELECT asInt64(1)")!, 1)
                XCTAssertEqual(Int64.fetchOne(db, "SELECT asInt64(1.1)")!, 1)
            }
        }
    }
    
    func testFunctionArgumentDouble() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asDouble", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as Double?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(Double.fetchOne(db, "SELECT asDouble(NULL)") == nil)
                XCTAssertEqual(Double.fetchOne(db, "SELECT asDouble(1)")!, 1.0)
                XCTAssertEqual(Double.fetchOne(db, "SELECT asDouble(1.1)")!, 1.1)
            }
        }
    }
    
    func testFunctionArgumentString() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asString", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as String?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(String.fetchOne(db, "SELECT asString(NULL)") == nil)
                XCTAssertEqual(String.fetchOne(db, "SELECT asString('foo')")!, "foo")
            }
        }
    }
    
    func testFunctionArgumentBlob() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asData", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as NSData?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(NSData.fetchOne(db, "SELECT asData(NULL)") == nil)
                XCTAssertEqual(NSData.fetchOne(db, "SELECT asData(?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)])!, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testFunctionArgumentCustomValueType() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("asCustomValueType", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as CustomValueType?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT asCustomValueType(NULL)") == nil)
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT asCustomValueType('CustomValueType')") != nil)
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
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
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
                return string.uppercaseString
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(String.fetchOne(db, "SELECT upper(?)", arguments: ["Roué"])!, "ROUé")
                XCTAssertEqual(String.fetchOne(db, "SELECT unicodeUpper(?)", arguments: ["Roué"])!, "ROUÉ")
                XCTAssertTrue(String.fetchOne(db, "SELECT unicodeUpper(NULL)") == nil)
            }
        }
    }
    
    func testFunctionOfTwoArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 2) { databaseValues in
                let ints: [Int] = databaseValues.flatMap { $0.value() }
                return ints.reduce(0, combine: +)
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1, 2)")!, 3)
            }
        }
    }
    
    func testVariadicFunction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f") { databaseValues in
                return databaseValues.count
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT f()")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1)")!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1, 1)")!, 2)
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
            dbQueue.addFunction(fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 1)
                    XCTAssertEqual(error.message, "custom error message")
                }
            }
        }
    }
    
    func testFunctionThrowingDatabaseErrorWithCode() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw DatabaseError(code: 123)
            }
            dbQueue.addFunction(fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 123)
                    XCTAssertEqual(error.message, "unknown error")
                }
            }
        }
    }
    
    func testFunctionThrowingDatabaseErrorWithMessageAndCode() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw DatabaseError(code: 123, message: "custom error message")
            }
            dbQueue.addFunction(fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 123)
                    XCTAssertEqual(error.message, "custom error message")
                }
            }
        }
    }
    
    func testFunctionThrowingCustomError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "custom error message"])
            }
            dbQueue.addFunction(fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 1)
                    XCTAssertTrue(error.message!.containsString("CustomErrorDomain"))
                    XCTAssertTrue(error.message!.containsString("123"))
                    XCTAssertTrue(error.message!.containsString("custom error message"))
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
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                x = 321
                XCTAssertEqual(Int.fetchOne(db, "SELECT f()")!, 321)
            }
        }
    }
}
