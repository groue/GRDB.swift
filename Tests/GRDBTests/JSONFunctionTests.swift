import XCTest
import GRDB

final class JSONFunctionTests: GRDBTestCase {
    
    private func assert<Output: DatabaseValueConvertible & Equatable>(
        _ db: Database,
        _ expression: SQLExpression,
        equal expectedOutput: Output,
        file: StaticString = #file,
        line: UInt = #line) throws
    {
        let request: SQLRequest<Output> = "SELECT \(expression)"
        guard let json = try request.fetchOne(db) else {
            XCTFail(file: file, line: line)
            return
        }
        XCTAssertEqual(json, expectedOutput, file: file, line: line)
    }
    
    func testJSON() throws {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            let dbQueue = try makeDatabaseQueue()
            
            let input = """
             { "this" : "is", "a": [ "test" ] }
            """.databaseValue
            
            let expected = """
            {"this":"is","a":["test"]}
            """
            
            try dbQueue.inDatabase { db in
                try assert(db, json(input), equal: expected)
            }
        }
    }
    
    func testJSONArray() throws {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inDatabase { db in
                try assert(
                    db,
                    jsonArray(
                        1.databaseValue,
                        2.databaseValue,
                        "3".databaseValue,
                        4.databaseValue
                    ),
                    equal: "[1,2,\"3\",4]"
                )
                try assert(
                    db,
                    jsonArray(
                        jsonArray(
                            1.databaseValue,
                            2.databaseValue,
                            "3".databaseValue,
                            4.databaseValue
                        )
                    ),
                    equal: "[[1,2,\"3\",4]]"
                )
                try assert(
                    db,
                    jsonArray(
                        1.databaseValue,
                        DatabaseValue.null,
                        "3".databaseValue,
                        json("[4,5]".databaseValue),
                        json("{\"six\":7.7}".databaseValue)
                    ),
                    equal: "[1,null,\"3\",[4,5],{\"six\":7.7}]"
                )
            }
        }
    }
    
    func testJSONArrayLength() throws {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inDatabase { db in
                try assert(db, jsonArrayLength("[1,2,3,4]".databaseValue), equal: 4)
                try assert(db, jsonArrayLength("{\"one\":[1,2,3]}".databaseValue), equal: 0)
            }
        }
    }
    
    func testJSONArrayLengthWithPath() throws {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inDatabase { db in
                try assert(db, jsonArrayLength("[1,2,3,4]".databaseValue, "$"), equal: 4)
                try assert(db, jsonArrayLength("[1,2,3,4]".databaseValue, "$[2]"), equal: 0)
            }
        }
    }
    
    func testJSONExtract() throws {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            let dbQueue = try makeDatabaseQueue()
            
            let input = """
            {"a":2,"c":[4,5,{"f":7}]}
            """.databaseValue
            
            try dbQueue.inDatabase { db in
                try assert(db, jsonExtract(input, "$"), equal: input)
                try assert(db, jsonExtract(input, "$.c"), equal: "[4,5,{\"f\":7}]")
                try assert(db, jsonExtract(input, "$.c[2]"), equal: "{\"f\":7}")
                try assert(db, jsonExtract(input, "$.c[2].f"), equal: 7)
                try assert(db, jsonExtract(input, "$.x"), equal: DatabaseValue.null)
                try assert(db, jsonExtract(input, "$.x", "$.a"), equal: "[null,2]")
            }
        }
    }
    
    func testIsJSONValid() throws {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            let dbQueue = try makeDatabaseQueue()
            
            try dbQueue.inDatabase { db in
                try assert(db, isJSONValid(#"{"x":35}"#.databaseValue), equal: 1)
                try assert(db,  isJSONValid(#"{"x":35"#.databaseValue), equal: 0)
            }
        }
    }
}
