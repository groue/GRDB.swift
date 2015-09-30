import XCTest
import GRDB

class StatementArguments_FoundationTests: GRDBTestCase {

    func testStatementArgumentsNSArrayInitializer() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = db.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
                let persons = [ // NSArray, because of the heterogeneous values
                    ["Arthur", 41],
                    ["Barbara", 38],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person))
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertEqual(rows[1].value(named: "age") as Int, 38)
            }
        }
    }
    
    func testStatementArgumentsNSDictionaryInitializer() {
        assertNoError {
            
            try dbQueue.inTransaction { db in
                
                let statement = db.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
                let persons = [// NSDictionary, because of the heterogeneous values
                    ["name": "Arthur", "age": 41],
                    ["name": "Barbara", "age": 38],
                ]
                for person in persons {
                    try statement.execute(arguments: StatementArguments(person))
                }
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 41)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertEqual(rows[1].value(named: "age") as Int, 38)
            }
        }
    }
}
