import XCTest
@testable import GRDB

class ForeignKeyInfoTests: GRDBTestCase {
    
    private func assertEqual(_ lhs: ForeignKeyInfo, _ rhs: ForeignKeyInfo, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.destinationTable, rhs.destinationTable, file: file, line: line)
        XCTAssertEqual(lhs.mapping.count, rhs.mapping.count, file: file, line: line)
        for (larrow, rarrow) in zip(lhs.mapping, rhs.mapping) {
            XCTAssertEqual(larrow.origin, rarrow.origin, file: file, line: line)
            XCTAssertEqual(larrow.destination, rarrow.destination, file: file, line: line)
        }
    }
    
    func testForeignKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE parents1 (id PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE parents2 (a, b, PRIMARY KEY (a,b))")
            try db.execute(sql: "CREATE TABLE children1 (parentId REFERENCES parents1)")
            try db.execute(sql: "CREATE TABLE children2 (parentId1 REFERENCES parents1, parentId2 REFERENCES parents1)")
            try db.execute(sql: "CREATE TABLE children3 (parentA, parentB, FOREIGN KEY (parentA, parentB) REFERENCES parents2)")
            try db.execute(sql: "CREATE TABLE children4 (parentA1, parentB1, parentA2, parentB2, FOREIGN KEY (parentA1, parentB1) REFERENCES parents2, FOREIGN KEY (parentA2, parentB2) REFERENCES parents2(b, a))")
            
            do {
                _ = try db.foreignKeys(on: "missing")
                XCTFail("Expected DatabaseError")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "no such table: missing")
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "parents1")
                XCTAssert(foreignKeys.isEmpty)
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "parents2")
                XCTAssert(foreignKeys.isEmpty)
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "children1")
                XCTAssertEqual(foreignKeys.count, 1)
                assertEqual(foreignKeys[0], ForeignKeyInfo(id: foreignKeys[0].id, destinationTable: "parents1", mapping: [(origin: "parentId", destination: "id")]))
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "children2")
                XCTAssertEqual(foreignKeys.count, 2)
                assertEqual(foreignKeys[0], ForeignKeyInfo(id: foreignKeys[0].id, destinationTable: "parents1", mapping: [(origin: "parentId2", destination: "id")]))
                assertEqual(foreignKeys[1], ForeignKeyInfo(id: foreignKeys[1].id, destinationTable: "parents1", mapping: [(origin: "parentId1", destination: "id")]))
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "children3")
                XCTAssertEqual(foreignKeys.count, 1)
                assertEqual(foreignKeys[0], ForeignKeyInfo(id: foreignKeys[0].id, destinationTable: "parents2", mapping: [(origin: "parentA", destination: "a"), (origin: "parentB", destination: "b")]))
            }
            
            do {
                let foreignKeys = try db.foreignKeys(on: "children4")
                XCTAssertEqual(foreignKeys.count, 2)
                assertEqual(foreignKeys[0], ForeignKeyInfo(id: foreignKeys[0].id, destinationTable: "parents2", mapping: [(origin: "parentA2", destination: "b"), (origin: "parentB2", destination: "a")]))
                assertEqual(foreignKeys[1], ForeignKeyInfo(id: foreignKeys[1].id, destinationTable: "parents2", mapping: [(origin: "parentA1", destination: "a"), (origin: "parentB1", destination: "b")]))
            }
        }
    }
    
    func testForeignKeyViolations() throws {
        try makeDatabaseQueue().writeWithoutTransaction { db in
            try db.execute(sql: """
                CREATE TABLE parent(id TEXT NOT NULL PRIMARY KEY);
                CREATE TABLE child1(id INTEGER NOT NULL PRIMARY KEY, parentId TEXT REFERENCES parent(id));
                CREATE TABLE child2(id INTEGER NOT NULL PRIMARY KEY, parentId TEXT REFERENCES parent(id));
                PRAGMA foreign_keys = OFF;
                INSERT INTO child1 (id, parentId) VALUES (13, '1');
                INSERT INTO child1 (id, parentId) VALUES (42, '2');
                INSERT INTO child2 (id, parentId) VALUES (17, '3');
                """)
            
            let violations = try Array(db.foreignKeyViolations())
            XCTAssertEqual(violations.count, 3)
            
            if let violation = violations.first(where: { $0.originTable == "child1" && $0.originRowID == 13 }) {
                XCTAssertEqual(violation.destinationTable, "parent")
            } else {
                XCTFail("Missing violation")
            }
            
            if let violation = violations.first(where: { $0.originTable == "child1" && $0.originRowID == 42 }) {
                XCTAssertEqual(violation.destinationTable, "parent")
            } else {
                XCTFail("Missing violation")
            }
            
            if let violation = violations.first(where: { $0.originTable == "child2" && $0.originRowID == 17 }) {
                XCTAssertEqual(violation.destinationTable, "parent")
            } else {
                XCTFail("Missing violation")
            }
        }
    }
    
    func testForeignKeyViolationsInTable() throws {
        try makeDatabaseQueue().writeWithoutTransaction { db in
            try db.execute(sql: """
                CREATE TABLE parent(id TEXT NOT NULL PRIMARY KEY);
                CREATE TABLE child1(id INTEGER NOT NULL PRIMARY KEY, parentId TEXT REFERENCES parent(id));
                CREATE TABLE child2(id INTEGER NOT NULL PRIMARY KEY, parentId TEXT REFERENCES parent(id));
                PRAGMA foreign_keys = OFF;
                INSERT INTO child1 (id, parentId) VALUES (13, '1');
                INSERT INTO child1 (id, parentId) VALUES (42, '2');
                INSERT INTO child2 (id, parentId) VALUES (17, '3');
                """)
            
            do {
                let violations = try Array(db.foreignKeyViolations(in: "child1"))
                XCTAssertEqual(violations.count, 2)
                
                if let violation = violations.first(where: { $0.originRowID == 13 }) {
                    XCTAssertEqual(violation.originTable, "child1")
                    XCTAssertEqual(violation.destinationTable, "parent")
                } else {
                    XCTFail("Missing violation")
                }
                
                if let violation = violations.first(where: { $0.originRowID == 42 }) {
                    XCTAssertEqual(violation.originTable, "child1")
                    XCTAssertEqual(violation.destinationTable, "parent")
                } else {
                    XCTFail("Missing violation")
                }
            }
            
            do {
                let violations = try Array(db.foreignKeyViolations(in: "child2"))
                XCTAssertEqual(violations.count, 1)
                
                if let violation = violations.first(where: { $0.originRowID == 17 }) {
                    XCTAssertEqual(violation.originTable, "child2")
                    XCTAssertEqual(violation.destinationTable, "parent")
                } else {
                    XCTFail("Missing violation")
                }
            }
            
            // Case insensitivity
            do {
                let violations = try Array(db.foreignKeyViolations(in: "cHiLd2"))
                XCTAssertEqual(violations.count, 1)
                
                if let violation = violations.first(where: { $0.originRowID == 17 }) {
                    XCTAssertEqual(violation.originTable, "child2")
                    XCTAssertEqual(violation.destinationTable, "parent")
                } else {
                    XCTFail("Missing violation")
                }
            }
            
            // Missing table
            do {
                _ = try db.foreignKeyViolations(in: "missing")
            } catch DatabaseError.SQLITE_ERROR { }
        }
    }
    
    func testCheckForeignKeys() throws {
        try makeDatabaseQueue().writeWithoutTransaction { db in
            try db.execute(sql: """
                CREATE TABLE parent(id TEXT NOT NULL PRIMARY KEY);
                CREATE TABLE child(id INTEGER NOT NULL PRIMARY KEY, parentId TEXT REFERENCES parent(id));
                PRAGMA foreign_keys = OFF;
                INSERT INTO child (id, parentId) VALUES (13, '1');
                """)
            
            do {
                try db.checkForeignKeys()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.message, #"FOREIGN KEY constraint violation - from child(parentId) to parent(id), in [id:13 parentId:"1"]"#)
                XCTAssertEqual(error.description, #"SQLite error 19: FOREIGN KEY constraint violation - from child(parentId) to parent(id), in [id:13 parentId:"1"]"#)
            }
        }
        
        try makeDatabaseQueue().writeWithoutTransaction { db in
            try db.execute(sql: """
                CREATE TABLE parent(a TEXT NOT NULL, b TEXT NOT NULL, PRIMARY KEY (a, b));
                CREATE TABLE child(id INTEGER NOT NULL PRIMARY KEY, parentA, parentB, FOREIGN KEY (parentA, parentB) REFERENCES parent(a, b));
                PRAGMA foreign_keys = OFF;
                INSERT INTO child (id, parentA, parentB) VALUES (13, 'foo', 'bar');
                """)
            
            do {
                try db.checkForeignKeys()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.message, #"FOREIGN KEY constraint violation - from child(parentA, parentB) to parent(a, b), in [id:13 parentA:"foo" parentB:"bar"]"#)
                XCTAssertEqual(error.description, #"SQLite error 19: FOREIGN KEY constraint violation - from child(parentA, parentB) to parent(a, b), in [id:13 parentA:"foo" parentB:"bar"]"#)
            }
        }
        
        try makeDatabaseQueue().writeWithoutTransaction { db in
            try db.execute(sql: """
                CREATE TABLE parent(a TEXT NOT NULL, b TEXT NOT NULL, PRIMARY KEY (a, b));
                CREATE TABLE child(id INTEGER NOT NULL PRIMARY KEY, parentA, parentB, FOREIGN KEY (parentA, parentB) REFERENCES parent(a, b)) WITHOUT ROWID;
                PRAGMA foreign_keys = OFF;
                INSERT INTO child (id, parentA, parentB) VALUES (13, 'foo', 'bar');
                """)
            
            do {
                try db.checkForeignKeys()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                XCTAssertEqual(error.extendedResultCode, .SQLITE_CONSTRAINT_FOREIGNKEY)
                XCTAssertEqual(error.message, "FOREIGN KEY constraint violation - from child(parentA, parentB) to parent(a, b)")
                XCTAssertEqual(error.description, "SQLite error 19: FOREIGN KEY constraint violation - from child(parentA, parentB) to parent(a, b)")
            }
        }
    }
}
