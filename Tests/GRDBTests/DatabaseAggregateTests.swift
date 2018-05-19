import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct CustomValueType : DatabaseValueConvertible {
    var databaseValue: DatabaseValue {
        return "CustomValueType".databaseValue
    }
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CustomValueType? {
        guard let string = String.fromDatabaseValue(dbValue), string == "CustomValueType" else {
            return nil
        }
        return CustomValueType()
    }
}

class DatabaseAggregateTests: GRDBTestCase {
    
    // MARK: - Return values

    func testAggregateReturningNull() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ values: [DatabaseValue]) { }
            func finalize() -> DatabaseValueConvertible? {
                return nil
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try DatabaseValue.fetchOne(db, "SELECT f()")!.isNull)
        }
    }

    func testAggregateReturningInt64() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ values: [DatabaseValue]) { }
            func finalize() -> DatabaseValueConvertible? {
                return Int64(1)
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Int64.fetchOne(db, "SELECT f()")!, Int64(1))
        }
    }

    func testAggregateReturningDouble() throws {
        let dbQueue = try makeDatabaseQueue()
        struct Aggregate : DatabaseAggregate {
            func step(_ values: [DatabaseValue]) { }
            func finalize() -> DatabaseValueConvertible? {
                return 1e100
            }
        }
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Double.fetchOne(db, "SELECT f()")!, 1e100)
        }
    }

    func testAggregateReturningString() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ values: [DatabaseValue]) { }
            func finalize() -> DatabaseValueConvertible? {
                return "foo"
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try String.fetchOne(db, "SELECT f()")!, "foo")
        }
    }

    func testAggregateReturningData() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ values: [DatabaseValue]) { }
            func finalize() -> DatabaseValueConvertible? {
                return "foo".data(using: .utf8)
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Data.fetchOne(db, "SELECT f()")!, "foo".data(using: .utf8))
        }
    }

    func testAggregateReturningCustomValueType() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ values: [DatabaseValue]) { }
            func finalize() -> DatabaseValueConvertible? {
                return CustomValueType()
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT f()") != nil)
        }
    }

    // MARK: - Argument values
    
    func testAggregateArgumentNil() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = dbValues[0].isNull
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try Bool.fetchOne(db, "SELECT f(NULL)")!)
            XCTAssertFalse(try Bool.fetchOne(db, "SELECT f(1)")!)
            XCTAssertFalse(try Bool.fetchOne(db, "SELECT f(1.1)")!)
            XCTAssertFalse(try Bool.fetchOne(db, "SELECT f('foo')")!)
            XCTAssertFalse(try Bool.fetchOne(db, "SELECT f(?)", arguments: ["foo".data(using: .utf8)])!)
            XCTAssertFalse(try Bool.fetchOne(db, "SELECT f(?)", arguments: [Data()])!)
        }
    }

    func testAggregateArgumentInt64() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = Int64.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try Int64.fetchOne(db, "SELECT f(NULL)") == nil)
            XCTAssertEqual(try Int64.fetchOne(db, "SELECT f(1)")!, 1)
            XCTAssertEqual(try Int64.fetchOne(db, "SELECT f(1.1)")!, 1)
        }
    }

    func testAggregateArgumentDouble() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = Double.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try Double.fetchOne(db, "SELECT f(NULL)") == nil)
            XCTAssertEqual(try Double.fetchOne(db, "SELECT f(1)")!, 1.0)
            XCTAssertEqual(try Double.fetchOne(db, "SELECT f(1.1)")!, 1.1)
        }
    }

    func testAggregateArgumentString() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = String.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try String.fetchOne(db, "SELECT f(NULL)") == nil)
            XCTAssertEqual(try String.fetchOne(db, "SELECT f('foo')")!, "foo")
        }
    }

    func testAggregateArgumentBlob() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = Data.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try Data.fetchOne(db, "SELECT f(NULL)") == nil)
            XCTAssertEqual(try Data.fetchOne(db, "SELECT f(?)", arguments: ["foo".data(using: .utf8)])!, "foo".data(using: .utf8))
            XCTAssertEqual(try Data.fetchOne(db, "SELECT f(?)", arguments: [Data()])!, Data())
        }
    }

    func testAggregateArgumentCustomValueType() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = CustomValueType.fromDatabaseValue(dbValues[0])
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT f(NULL)") == nil)
            XCTAssertTrue(try CustomValueType.fetchOne(db, "SELECT f('CustomValueType')") != nil)
        }
    }

    // MARK: - Argument count
    
    func testAggregateWithoutArgument() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) { }
            func finalize() -> DatabaseValueConvertible? {
                return "foo"
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try String.fetchOne(db, "SELECT f()")!, "foo")
            do {
                try db.execute("SELECT f(1)")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f(1)")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT f(1)`: wrong number of arguments to function f()")
            }
        }
    }

    func testAggregateOfOneArgument() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = String.fromDatabaseValue(dbValues[0])?.uppercased()
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try String.fetchOne(db, "SELECT upper(?)", arguments: ["Roué"])!, "ROUé")
            XCTAssertEqual(try String.fetchOne(db, "SELECT f(?)", arguments: ["Roué"])!, "ROUÉ")
            XCTAssertTrue(try String.fetchOne(db, "SELECT f(NULL)") == nil)
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f()")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT f()`: wrong number of arguments to function f()")
            }
        }
    }

    func testAggregateOfTwoArguments() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                let ints = dbValues.compactMap { Int.fromDatabaseValue($0) }
                result = ints.reduce(0, +)
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 2, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Int.fetchOne(db, "SELECT f(1, 2)")!, 3)
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "wrong number of arguments to function f()")
                XCTAssertEqual(error.sql!, "SELECT f()")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT f()`: wrong number of arguments to function f()")
            }
        }
    }

    func testVariadicFunction() throws {
        struct Aggregate : DatabaseAggregate {
            var result: DatabaseValueConvertible?
            mutating func step(_ dbValues: [DatabaseValue]) {
                result = dbValues.count
            }
            func finalize() -> DatabaseValueConvertible? {
                return result
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Int.fetchOne(db, "SELECT f()")!, 0)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT f(1)")!, 1)
            XCTAssertEqual(try Int.fetchOne(db, "SELECT f(1, 1)")!, 2)
        }
    }

    // MARK: - Step Errors

    func testAggregateStepThrowingDatabaseErrorWithMessage() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) throws {
                throw DatabaseError(message: "custom error message")
            }
            func finalize() -> DatabaseValueConvertible? {
                fatalError()
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }

    func testAggregateStepThrowingDatabaseErrorWithCode() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) throws {
                throw DatabaseError(resultCode: ResultCode(rawValue: 123))
            }
            func finalize() -> DatabaseValueConvertible? {
                fatalError()
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "unknown error")
            }
        }
    }

    func testAggregateStepThrowingDatabaseErrorWithMessageAndCode() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) throws {
                throw DatabaseError(resultCode: ResultCode(rawValue: 123), message: "custom error message")
            }
            func finalize() -> DatabaseValueConvertible? {
                fatalError()
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }

    func testAggregateStepThrowingCustomError() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) throws {
                throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "custom error message"])
            }
            func finalize() -> DatabaseValueConvertible? {
                fatalError()
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertTrue(error.message!.contains("CustomErrorDomain"))
                XCTAssertTrue(error.message!.contains("123"))
                XCTAssertTrue(error.message!.contains("custom error message"))
            }
        }
    }
    
    // MARK: - Result Errors
    
    func testAggregateResultThrowingDatabaseErrorWithMessage() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) { }
            func finalize() throws -> DatabaseValueConvertible? {
                throw DatabaseError(message: "custom error message")
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }
    
    func testAggregateResultThrowingDatabaseErrorWithCode() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) { }
            func finalize() throws -> DatabaseValueConvertible? {
                throw DatabaseError(resultCode: ResultCode(rawValue: 123))
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "unknown error")
            }
        }
    }
    
    func testAggregateResultThrowingDatabaseErrorWithMessageAndCode() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) { }
            func finalize() throws -> DatabaseValueConvertible? {
                throw DatabaseError(resultCode: ResultCode(rawValue: 123), message: "custom error message")
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 123)
                XCTAssertEqual(error.message, "custom error message")
            }
        }
    }
    
    func testAggregateResultThrowingCustomError() throws {
        struct Aggregate : DatabaseAggregate {
            func step(_ dbValues: [DatabaseValue]) { }
            func finalize() throws -> DatabaseValueConvertible? {
                throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "custom error message"])
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            do {
                try db.execute("SELECT f()")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertTrue(error.message!.contains("CustomErrorDomain"))
                XCTAssertTrue(error.message!.contains("123"))
                XCTAssertTrue(error.message!.contains("custom error message"))
            }
        }
    }
    
    // MARK: - Aggregation
    
    func testAggregation() throws {
        struct Aggregate : DatabaseAggregate {
            var sum: Int?
            mutating func step(_ dbValues: [DatabaseValue]) {
                if let int = Int.fromDatabaseValue(dbValues[0]) {
                    sum = (sum ?? 0) + int
                }
            }
            func finalize() throws -> DatabaseValueConvertible? {
                return sum
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(try Int.fetchOne(db, "SELECT f(a) FROM (SELECT 1 AS a UNION ALL SELECT 2 UNION ALL SELECT 3)")!, 6)
        }
    }
    
    func testParallelAggregation() throws {
        struct Aggregate : DatabaseAggregate {
            var sum: Int?
            mutating func step(_ dbValues: [DatabaseValue]) {
                if let int = Int.fromDatabaseValue(dbValues[0]) {
                    sum = (sum ?? 0) + int
                }
            }
            func finalize() throws -> DatabaseValueConvertible? {
                return sum
            }
        }
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 1, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            let row = try Row.fetchOne(db, "SELECT f(a), f(b) FROM (SELECT 1 AS a, 2 AS b UNION ALL SELECT 2, 4 UNION ALL SELECT 3, 6)")!
            XCTAssertEqual(row[0], 6)
            XCTAssertEqual(row[1], 12)
        }
    }
    
    // MARK: - Deallocation
    
    func testDeallocationAfterSuccess() throws {
        final class Aggregate : DatabaseAggregate {
            static var onInit: (() -> ())?
            static var onDeinit: (() -> ())?
            init() { Aggregate.onInit?() }
            deinit { Aggregate.onDeinit?() }
            func step(_ dbValues: [DatabaseValue]) { }
            func finalize() -> DatabaseValueConvertible? {
                return nil
            }
        }
        var allocationCount = 0
        var aliveCount = 0
        Aggregate.onInit = {
            allocationCount += 1
            aliveCount += 1
        }
        Aggregate.onDeinit = {
            aliveCount -= 1
        }
        
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        try dbQueue.inDatabase { db in
            XCTAssertEqual(allocationCount, 0)
            XCTAssertEqual(aliveCount, 0)
            try db.execute("SELECT f()")
            XCTAssertEqual(allocationCount, 1)
            XCTAssertEqual(aliveCount, 0)
        }
    }
    
    func testDeallocationAfterStepError() throws {
        final class Aggregate : DatabaseAggregate {
            static var onInit: (() -> ())?
            static var onDeinit: (() -> ())?
            init() { Aggregate.onInit?() }
            deinit { Aggregate.onDeinit?() }
            func step(_ dbValues: [DatabaseValue]) throws {
                throw DatabaseError(message: "boo")
            }
            func finalize() -> DatabaseValueConvertible? {
                fatalError()
            }
        }
        var allocationCount = 0
        var aliveCount = 0
        Aggregate.onInit = {
            allocationCount += 1
            aliveCount += 1
        }
        Aggregate.onDeinit = {
            aliveCount -= 1
        }
        
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        dbQueue.inDatabase { db in
            XCTAssertEqual(allocationCount, 0)
            XCTAssertEqual(aliveCount, 0)
            _ = try? db.execute("SELECT f()")
            XCTAssertEqual(allocationCount, 1)
            XCTAssertEqual(aliveCount, 0)
        }
    }
    
    func testDeallocationAfterResultError() throws {
        final class Aggregate : DatabaseAggregate {
            static var onInit: (() -> ())?
            static var onDeinit: (() -> ())?
            init() { Aggregate.onInit?() }
            deinit { Aggregate.onDeinit?() }
            func step(_ dbValues: [DatabaseValue]) { }
            func finalize() throws -> DatabaseValueConvertible? {
                throw DatabaseError(message: "boo")
            }
        }
        
        var allocationCount = 0
        var aliveCount = 0
        Aggregate.onInit = {
            allocationCount += 1
            aliveCount += 1
        }
        Aggregate.onDeinit = {
            aliveCount -= 1
        }
        
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("f", argumentCount: 0, aggregate: Aggregate.self)
        dbQueue.add(function: fn)
        dbQueue.inDatabase { db in
            XCTAssertEqual(allocationCount, 0)
            XCTAssertEqual(aliveCount, 0)
            _ = try? db.execute("SELECT f()")
            XCTAssertEqual(allocationCount, 1)
            XCTAssertEqual(aliveCount, 0)
        }
    }
}
