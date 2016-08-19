import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class JoinTests: GRDBTestCase {
    func testAvailableScopesWithNestedJoins() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // a <- b <- c <- d
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id))")
                try db.execute("CREATE TABLE c (id INTEGER PRIMARY KEY, bID REFERENCES b(id))")
                try db.execute("CREATE TABLE d (id INTEGER PRIMARY KEY, cID REFERENCES c(id))")
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                try db.execute("INSERT INTO b (id, aID) VALUES (NULL, ?)", arguments: [db.lastInsertedRowID])
                try db.execute("INSERT INTO c (id, bID) VALUES (NULL, ?)", arguments: [db.lastInsertedRowID])
                try db.execute("INSERT INTO d (id, cID) VALUES (NULL, ?)", arguments: [db.lastInsertedRowID])
                
                let b = Relation(to: "b", columns: ["aID"])
                let c = Relation(to: "c", columns: ["bID"])
                let d = Relation(to: "d", columns: ["cID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.join(b)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) == nil)
                    XCTAssertTrue(row.scoped(on: b, c) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                }
                
                do {
                    let request = A.include(b)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) == nil)
                    XCTAssertTrue(row.scoped(on: b, c) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)

                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                }
                
                do {
                    let request = A.join(b.join(c))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) == nil)
                    XCTAssertTrue(row.scoped(on: b, c) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                }
                
                do {
                    let request = A.include(b.join(c))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) == nil)
                    XCTAssertTrue(row.scoped(on: b, c) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                    
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                }
                
                do {
                    let request = A.join(b.include(c))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) != nil)
                    XCTAssertTrue(row.scoped(on: b, c) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                    
                    XCTAssertTrue(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c)!.isEmpty)
                }
                
                do {
                    let request = A.include(b.include(c))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) != nil)
                    XCTAssertTrue(row.scoped(on: b, c) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                    
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c)!.isEmpty)
                }
                
                do {
                    let request = A.join(b.join(c.join(d)))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "LEFT JOIN \"d\" ON (\"d\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) == nil)
                    XCTAssertTrue(row.scoped(on: b, c) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                }
                
                do {
                    let request = A.include(b.join(c.join(d)))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "LEFT JOIN \"d\" ON (\"d\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) == nil)
                    XCTAssertTrue(row.scoped(on: b, c) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                    
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                }
                
                do {
                    let request = A.join(b.include(c.join(d)))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "LEFT JOIN \"d\" ON (\"d\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) != nil)
                    XCTAssertTrue(row.scoped(on: b, c) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                    
                    XCTAssertTrue(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c)!.isEmpty)
                }
                
                do {
                    let request = A.include(b.include(c.join(d)))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "LEFT JOIN \"d\" ON (\"d\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) != nil)
                    XCTAssertTrue(row.scoped(on: b, c) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) == nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) == nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) == nil)
                    
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c)!.isEmpty)
                }
                
                do {
                    let request = A.join(b.join(c.include(d)))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"d\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "LEFT JOIN \"d\" ON (\"d\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) != nil)
                    XCTAssertTrue(row.scoped(on: b, c) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) != nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) != nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) != nil)
                    
                    XCTAssertTrue(row.scoped(on: b)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: b, c)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c, d)!.isEmpty)
                }
                
                do {
                    let request = A.include(b.join(c.include(d)))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"d\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "LEFT JOIN \"d\" ON (\"d\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) != nil)
                    XCTAssertTrue(row.scoped(on: b, c) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) != nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) != nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) != nil)
                    
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: b, c)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c, d)!.isEmpty)
                }
                
                do {
                    let request = A.join(b.include(c.include(d)))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"c\".*, \"d\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "LEFT JOIN \"d\" ON (\"d\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) != nil)
                    XCTAssertTrue(row.scoped(on: b, c) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) != nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) != nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) != nil)
                    
                    XCTAssertTrue(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c, d)!.isEmpty)
                }
                
                do {
                    let request = A.include(b.include(c.include(d)))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c\".*, \"d\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "LEFT JOIN \"d\" ON (\"d\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c) != nil)
                    XCTAssertTrue(row.scoped(on: b, c) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c)?.scoped(on: d) != nil)
                    XCTAssertTrue(row.scoped(on: b, c)?.scoped(on: d) != nil)
                    XCTAssertTrue(row.scoped(on: b)?.scoped(on: c, d) != nil)
                    XCTAssertTrue(row.scoped(on: b, c, d) != nil)
                    
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b, c, d)!.isEmpty)
                }
            }
        }
    }
    
    func testAvailableScopesWithSiblingJoins() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id))")
                try db.execute("CREATE TABLE c (id INTEGER PRIMARY KEY, a0ID REFERENCES a(id), a1ID REFERENCES a(id))")
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                let a0ID = db.lastInsertedRowID
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                let a1ID = db.lastInsertedRowID
                try db.execute("INSERT INTO b (id, aID) VALUES (NULL, ?)", arguments: [a0ID])
                try db.execute("INSERT INTO c (id, a0ID, a1ID) VALUES (NULL, ?, ?)", arguments: [a0ID, a1ID])
                
                let b = Relation(to: "b", columns: ["aID"])
                let c0 = Relation(to: "c", columns: ["a0ID"])
                let c1 = Relation(to: "c", columns: ["a1ID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.join(b, c0, c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: c0) == nil)
                    XCTAssertTrue(row.scoped(on: c1) == nil)
                }
                
                do {
                    let request = A.join(b).join(c0, c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: c0) == nil)
                    XCTAssertTrue(row.scoped(on: c1) == nil)
                }
                
                do {
                    let request = A.join(b, c0).join(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: c0) == nil)
                    XCTAssertTrue(row.scoped(on: c1) == nil)
                }
                
                do {
                    let request = A.join(b).join(c0).join(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: c0) == nil)
                    XCTAssertTrue(row.scoped(on: c1) == nil)
                }
                
                do {
                    let request = A.join(b, c0).include(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.join(b).join(c0).include(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.join(b).include(c0).join(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"c0\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.join(b).include(c0, c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"c0\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.join(b).include(c0).include(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"c0\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b).join(c0, c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b).join(c0).join(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b).join(c0).include(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b, c0).join(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c0\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b).include(c0).join(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c0\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b, c0, c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c0\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b).include(c0, c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c0\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b, c0).include(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c0\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
                
                do {
                    let request = A.include(b).include(c0).include(c1)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c0\".*, \"c1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" \"c0\" ON (\"c0\".\"a0ID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"c\" \"c1\" ON (\"c1\".\"a1ID\" = \"a\".\"id\")")
                    
                    let rows = Row.fetchAll(db, request)
                    if let index = rows.indexOf({ $0.value(named: "id") == a0ID }) {
                        let row = rows[index]
                        XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                        XCTAssertFalse(row.scoped(on: c0)!.isEmpty)
                        XCTAssertTrue(row.scoped(on: c1) == nil)
                    } else {
                        XCTFail()
                    }
                    if let index = rows.indexOf({ $0.value(named: "id") == a1ID }) {
                        let row = rows[index]
                        XCTAssertTrue(row.scoped(on: b) == nil)
                        XCTAssertTrue(row.scoped(on: c0) == nil)
                        XCTAssertFalse(row.scoped(on: c1)!.isEmpty)
                    } else {
                        XCTFail()
                    }
                }
            }
        }
    }
    
    func testAvailableScopesWithDiamondJoins() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // a <- b <- d
                // a <- c <- d
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id))")
                try db.execute("CREATE TABLE c (id INTEGER PRIMARY KEY, aID REFERENCES b(id))")
                try db.execute("CREATE TABLE d (id INTEGER PRIMARY KEY, bID REFERENCES b(id), cID REFERENCES c(id))")
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                let aID = db.lastInsertedRowID
                try db.execute("INSERT INTO b (id, aID) VALUES (NULL, ?)", arguments: [aID])
                let bID = db.lastInsertedRowID
                try db.execute("INSERT INTO c (id, aID) VALUES (NULL, ?)", arguments: [aID])
                let cID = db.lastInsertedRowID
                try db.execute("INSERT INTO d (id, bID, cID) VALUES (NULL, ?, ?)", arguments: [bID, cID])
                
                let b = Relation(to: "b", columns: ["aID"])
                let c = Relation(to: "c", columns: ["aID"])
                let bd = Relation(to: "d", columns: ["bID"])
                let cd = Relation(to: "d", columns: ["cID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.join(b.join(bd), c.join(cd))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: c) == nil)
                }
                
                do {
                    let request = A.include(b.join(bd), c.join(cd))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: b)!.scoped(on: bd) == nil)
                    XCTAssertFalse(row.scoped(on: c)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: c)!.scoped(on: cd) == nil)
                }
                
                do {
                    let request = A.join(b.include(bd), c.join(cd))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"d0\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b)!.scoped(on: bd)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: c) == nil)
                }
                
                do {
                    let request = A.include(b.include(bd), c.join(cd))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"d0\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b)!.scoped(on: bd)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: c)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: c)!.scoped(on: cd) == nil)
                }
                
                do {
                    let request = A.join(b.join(bd), c.include(cd))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"d1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) == nil)
                    XCTAssertTrue(row.scoped(on: c)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: c)!.scoped(on: cd)!.isEmpty)
                }
                
                do {
                    let request = A.include(b.join(bd), c.include(cd))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c\".*, \"d1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: b)!.scoped(on: bd) == nil)
                    XCTAssertFalse(row.scoped(on: c)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: c)!.scoped(on: cd)!.isEmpty)
                }
                
                do {
                    let request = A.join(b.include(bd), c.include(cd))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"d0\".*, \"d1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b)!.scoped(on: bd)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: c)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: c)!.scoped(on: cd)!.isEmpty)
                }
                
                do {
                    let request = A.include(b.include(bd), c.include(cd))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"d0\".*, \"c\".*, \"d1\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                        "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: b)!.scoped(on: bd)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: c)!.isEmpty)
                    XCTAssertFalse(row.scoped(on: c)!.scoped(on: cd)!.isEmpty)
                }
            }
        }
    }
    
    func testRelationAlias() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id))")
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                try db.execute("INSERT INTO b (id, aID) VALUES (NULL, ?)", arguments: [db.lastInsertedRowID])
                
                let b = Relation(to: "b", columns: ["aID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.include(b)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                }
                
                do {
                    let aliasedRelation = b.aliased("bAlias")
                    let request = A.include(aliasedRelation)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"bAlias\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" \"bAlias\" ON (\"bAlias\".\"aID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: aliasedRelation) != nil)
                    XCTAssertFalse(row.scoped(on: aliasedRelation)!.isEmpty)
                    XCTAssertTrue(row.scoped(on: "bAlias") == nil)
                }
            }
        }
    }
    
    func testJoinConflict() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("PRAGMA defer_foreign_keys = ON")
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY, bID REFERENCES b(id))")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id))")
                try db.execute("INSERT INTO a (id, bID) VALUES (?, ?)", arguments: [1, 1])
                try db.execute("INSERT INTO b (id, aID) VALUES (?, ?)", arguments: [1, 1])
                return .Commit
            }
            
            let b = Relation(to: "b", columns: ["aID"])
            let a = Relation(to: "a", columns: ["bID"])
            
            struct A : TableMapping {
                static func databaseTableName() -> String { return "a" }
            }
            
            dbQueue.inDatabase { db in
                let request = A.include(b.include(a))
                XCTAssertEqual(
                    self.sql(db, request),
                    "SELECT \"a0\".*, \"b\".*, \"a1\".* " +
                        "FROM \"a\" \"a0\" " +
                        "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a0\".\"id\") " +
                    "LEFT JOIN \"a\" \"a1\" ON (\"a1\".\"bID\" = \"b\".\"id\")")
                
                let row = Row.fetchOne(db, request)!
                XCTAssertTrue(row.scoped(on: b) != nil)
                XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                XCTAssertTrue(row.scoped(on: b)!.scoped(on: a) != nil)
                XCTAssertFalse(row.scoped(on: b)!.scoped(on: a)!.isEmpty)
            }
            
            dbQueue.inDatabase { db in
                let request = A.include(b.include(a.include(b)))
                XCTAssertEqual(
                    self.sql(db, request),
                    "SELECT \"a0\".*, \"b0\".*, \"a1\".*, \"b1\".* " +
                        "FROM \"a\" \"a0\" " +
                        "LEFT JOIN \"b\" \"b0\" ON (\"b0\".\"aID\" = \"a0\".\"id\") " +
                        "LEFT JOIN \"a\" \"a1\" ON (\"a1\".\"bID\" = \"b0\".\"id\") " +
                    "LEFT JOIN \"b\" \"b1\" ON (\"b1\".\"aID\" = \"a1\".\"id\")")
                
                let row = Row.fetchOne(db, request)!
                XCTAssertTrue(row.scoped(on: b) != nil)
                XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                XCTAssertTrue(row.scoped(on: b)!.scoped(on: a) != nil)
                XCTAssertFalse(row.scoped(on: b)!.scoped(on: a)!.isEmpty)
                XCTAssertTrue(row.scoped(on: b)!.scoped(on: a)!.scoped(on: b) != nil)
                XCTAssertFalse(row.scoped(on: b)!.scoped(on: a)!.scoped(on: b)!.isEmpty)
            }
        }
    }
    
    func testJoinConflict2() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "persons") { t in
                    t.column("id", .Integer).primaryKey()
                    t.column("name", .Text)
                    t.column("fatherId", .Integer).references("persons")
                    t.column("motherId", .Integer).references("persons")
                }
            }
            
            class Person : TableMapping {
                static func databaseTableName() -> String { return "persons" }
            }
            
            let father = Relation(to: "persons", fromColumns: ["fatherId"])
            let mother = Relation(to: "persons", fromColumns: ["motherId"])
            
            dbQueue.inDatabase { db in
                let request = Person.include(
                    father.include(father, mother),
                    mother.include(father, mother))
                XCTAssertEqual(
                    self.sql(db, request),
                    "SELECT \"persons0\".*, \"persons1\".*, \"persons2\".*, \"persons3\".*, \"persons4\".*, \"persons5\".*, \"persons6\".* " +
                        "FROM \"persons\" \"persons0\" " +
                        "LEFT JOIN \"persons\" \"persons1\" ON (\"persons1\".\"id\" = \"persons0\".\"fatherId\") " +
                        "LEFT JOIN \"persons\" \"persons2\" ON (\"persons2\".\"id\" = \"persons1\".\"fatherId\") " +
                        "LEFT JOIN \"persons\" \"persons3\" ON (\"persons3\".\"id\" = \"persons1\".\"motherId\") " +
                        "LEFT JOIN \"persons\" \"persons4\" ON (\"persons4\".\"id\" = \"persons0\".\"motherId\") " +
                        "LEFT JOIN \"persons\" \"persons5\" ON (\"persons5\".\"id\" = \"persons4\".\"fatherId\") " +
                    "LEFT JOIN \"persons\" \"persons6\" ON (\"persons6\".\"id\" = \"persons4\".\"motherId\")")
            }
        }
    }
    
    func testJoinOnClause() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY, foo TEXT)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id), bar TEXT, foo TEXT)")
                try db.execute("INSERT INTO a (id, foo) VALUES (NULL, ?)", arguments: ["foo"])
                try db.execute("INSERT INTO b (id, aID, bar, foo) VALUES (NULL, ?, ?, ?)", arguments: [db.lastInsertedRowID, "bar", "foo"])
                
                let barColumn = SQLColumn("bar")
                let b = Relation(to: "b", columns: ["aID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.include(b.on { $0["foo"] == "foo" && $0[barColumn] == "bar" })
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" ON ((\"b\".\"aID\" = \"a\".\"id\") AND ((\"b\".\"foo\" = 'foo') AND (\"b\".\"bar\" = 'bar')))")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                }
                
                do {
                    let request = A.include(b.aliased("bAlias").on { $0["foo"] == "foo" && $0[barColumn] == "bar" })
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"bAlias\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" \"bAlias\" ON ((\"bAlias\".\"aID\" = \"a\".\"id\") AND ((\"bAlias\".\"foo\" = 'foo') AND (\"bAlias\".\"bar\" = 'bar')))")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                }
            }
        }
    }
    
    func testJoinLiteralOnClause() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY, foo TEXT)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id), bar TEXT)")
                try db.execute("INSERT INTO a (id, foo) VALUES (NULL, ?)", arguments: ["foo"])
                try db.execute("INSERT INTO b (id, aID, bar) VALUES (NULL, ?, ?)", arguments: [db.lastInsertedRowID, "bar"])
                
                let b = Relation(to: "b", columns: ["aID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.include(b.on(sql: "b.bar = ?", arguments: ["bar"]))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" ON ((\"b\".\"aID\" = \"a\".\"id\") AND (b.bar = 'bar'))")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                }
                
                do {
                    let request = A.include(b.aliased("bAlias").on(sql: "bAlias.bar = ?", arguments: ["bar"]))
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"bAlias\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" \"bAlias\" ON ((\"bAlias\".\"aID\" = \"a\".\"id\") AND (bAlias.bar = 'bar'))")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) != nil)
                    XCTAssertFalse(row.scoped(on: b)!.isEmpty)
                }
            }
        }
    }
    
    func testJoinConflictWithOnClause() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("PRAGMA defer_foreign_keys = ON")
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY, bID REFERENCES b(id), foo TEXT)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id), bar TEXT)")
                try db.execute("INSERT INTO a (id, bID, foo) VALUES (?, ?, ?)", arguments: [1, 1, "foo"])
                try db.execute("INSERT INTO b (id, aID, bar) VALUES (?, ?, ?)", arguments: [1, 1, "bar"])
                return .Commit
            }
            
            let b = Relation(to: "b", columns: ["aID"])
            let a = Relation(to: "a", columns: ["bID"])
            
            struct A : TableMapping {
                static func databaseTableName() -> String { return "a" }
            }
            
            dbQueue.inDatabase { db in
                let request = A.filter { $0["foo"] == "foo1" }
                    .include(b.on { $0["bar"] == "bar" }
                        .include(a.on { $0["foo"] == "foo2" }))
                XCTAssertEqual(
                    self.sql(db, request),
                    "SELECT \"a0\".*, \"b\".*, \"a1\".* " +
                        "FROM \"a\" \"a0\" " +
                        "LEFT JOIN \"b\" ON ((\"b\".\"aID\" = \"a0\".\"id\") AND (\"b\".\"bar\" = 'bar')) " +
                        "LEFT JOIN \"a\" \"a1\" ON ((\"a1\".\"bID\" = \"b\".\"id\") AND (\"a1\".\"foo\" = 'foo2')) " +
                    "WHERE (\"a0\".\"foo\" = 'foo1')")
            }
            
            dbQueue.inDatabase { db in
                let request = A.filter { $0["foo"] == "foo1" }
                    .include(b.on { $0["bar"] == "bar1" }
                        .include(a.on { $0["foo"] == "foo2" }
                            .include(b.on { $0["bar"] == "bar2" })))
                XCTAssertEqual(
                    self.sql(db, request),
                    "SELECT \"a0\".*, \"b0\".*, \"a1\".*, \"b1\".* " +
                        "FROM \"a\" \"a0\" " +
                        "LEFT JOIN \"b\" \"b0\" ON ((\"b0\".\"aID\" = \"a0\".\"id\") AND (\"b0\".\"bar\" = 'bar1')) " +
                        "LEFT JOIN \"a\" \"a1\" ON ((\"a1\".\"bID\" = \"b0\".\"id\") AND (\"a1\".\"foo\" = 'foo2')) " +
                        "LEFT JOIN \"b\" \"b1\" ON ((\"b1\".\"aID\" = \"a1\".\"id\") AND (\"b1\".\"bar\" = 'bar2')) " +
                    "WHERE (\"a0\".\"foo\" = 'foo1')")
            }
        }
    }
    
    func testFirstLevelRequiredJoin() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id))")
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                
                let b = Relation(to: "b", columns: ["aID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.include(b)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)!
                    XCTAssertTrue(row.scoped(on: b) == nil)
                }
                
                do {
                    let request = A.include(required: b)
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".* " +
                            "FROM \"a\" " +
                        "JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\")")
                    
                    let row = Row.fetchOne(db, request)
                    XCTAssertTrue(row == nil)
                }
            }
        }
    }
    
    func testTwoLevelsRequiredJoin() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id))")
                try db.execute("CREATE TABLE c (id INTEGER PRIMARY KEY, bID REFERENCES b(id))")
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                try db.execute("INSERT INTO b (id, aID) VALUES (NULL, ?)", arguments: [db.lastInsertedRowID])
                try db.execute("INSERT INTO a (id) VALUES (NULL)")
                try db.execute("INSERT INTO b (id, aID) VALUES (NULL, ?)", arguments: [db.lastInsertedRowID])
                try db.execute("INSERT INTO c (id, bID) VALUES (NULL, ?)", arguments: [db.lastInsertedRowID])
                
                let b = Relation(to: "b", columns: ["aID"])
                let c = Relation(to: "c", columns: ["bID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.include(b.include(c)).order(sql: "a.id, b.id, c.id")
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "ORDER BY a.id, b.id, c.id")
                    
                    let rows = Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                }
                
                do {
                    let request = A.include(required: b.include(c)).order(sql: "a.id, b.id, c.id")
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "ORDER BY a.id, b.id, c.id")
                    
                    let rows = Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                }
                
                do {
                    let request = A.include(required: b.include(required: c)).order(sql: "a.id, b.id, c.id")
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".*, \"c\".* " +
                            "FROM \"a\" " +
                            "JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "JOIN \"c\" ON (\"c\".\"bID\" = \"b\".\"id\") " +
                        "ORDER BY a.id, b.id, c.id")
                    
                    let rows = Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 1)
                }
            }
        }
    }
    
    func testJoinSelection() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY, foo TEXT)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id), bar TEXT, foo TEXT)")
                try db.execute("INSERT INTO a (id, foo) VALUES (NULL, ?)", arguments: ["foo"])
                try db.execute("INSERT INTO b (id, aID, bar, foo) VALUES (NULL, ?, ?, ?)", arguments: [db.lastInsertedRowID, "bar", "foo"])
                
                let barColumn = SQLColumn("bar")
                let b = Relation(to: "b", columns: ["aID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    let request = A.include(b.select { [$0["foo"], $0[barColumn]] })
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".*, \"b\".\"foo\", \"b\".\"bar\" " +
                            "FROM \"a\" " +
                        "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\")")
                }
            }
        }
    }
    
    func testJoinSelectionWithConflict() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("PRAGMA defer_foreign_keys = ON")
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY, bID REFERENCES b(id), foo TEXT)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id), bar TEXT)")
                try db.execute("INSERT INTO a (id, bID, foo) VALUES (?, ?, ?)", arguments: [1, 1, "foo"])
                try db.execute("INSERT INTO b (id, aID, bar) VALUES (?, ?, ?)", arguments: [1, 1, "bar"])
                return .Commit
            }
            
            let b = Relation(to: "b", columns: ["aID"])
            let a = Relation(to: "a", columns: ["bID"])
            
            struct A : TableMapping {
                static func databaseTableName() -> String { return "a" }
            }
            
            dbQueue.inDatabase { db in
                let request = A.select { [$0["foo"]] }
                    .include(b.select { [$0["bar"]] }
                        .include(a.select { [$0["id"]] }))
                XCTAssertEqual(
                    self.sql(db, request),
                    "SELECT \"a0\".\"foo\", \"b\".\"bar\", \"a1\".\"id\" " +
                        "FROM \"a\" \"a0\" " +
                        "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a0\".\"id\") " +
                    "LEFT JOIN \"a\" \"a1\" ON (\"a1\".\"bID\" = \"b\".\"id\")")
            }
            
            dbQueue.inDatabase { db in
                let request = A.select { [$0["foo"]] }
                    .include(b.select { [$0["bar"]] }
                        .include(a.select { [$0["id"]] }
                            .include(b.select { [$0["id"]] })))
                XCTAssertEqual(
                    self.sql(db, request),
                    "SELECT \"a0\".\"foo\", \"b0\".\"bar\", \"a1\".\"id\", \"b1\".\"id\" " +
                        "FROM \"a\" \"a0\" " +
                        "LEFT JOIN \"b\" \"b0\" ON (\"b0\".\"aID\" = \"a0\".\"id\") " +
                        "LEFT JOIN \"a\" \"a1\" ON (\"a1\".\"bID\" = \"b0\".\"id\") " +
                    "LEFT JOIN \"b\" \"b1\" ON (\"b1\".\"aID\" = \"a1\".\"id\")")
            }
        }
    }
    
    func testFilteringOnScopes() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // a <- b <- d
                // a <- c <- d
                try db.execute("CREATE TABLE a (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE b (id INTEGER PRIMARY KEY, aID REFERENCES a(id))")
                try db.execute("CREATE TABLE c (id INTEGER PRIMARY KEY, aID REFERENCES b(id))")
                try db.execute("CREATE TABLE d (id INTEGER PRIMARY KEY, bID REFERENCES b(id), cID REFERENCES c(id))")
                
                let b = Relation(to: "b", columns: ["aID"])
                let c = Relation(to: "c", columns: ["aID"])
                let bd = Relation(to: "d", columns: ["bID"])
                let cd = Relation(to: "d", columns: ["cID"])
                
                struct A : TableMapping {
                    static func databaseTableName() -> String { return "a" }
                }
                
                do {
                    // scopes:
                    // - n/d
                    // - b
                    // - b, d
                    // - c,
                    // - c, d
                    let request = A.join(b.join(bd), c.join(cd))
                        .filter {
                            var test = ($0["id"] == 0)
                            test = test && ($0.scoped(on: b)["id"] == 1)
                            test = test && ($0.scoped(on: b, bd)["id"] == 2)
                            test = test && ($0.scoped(on: c)["id"] == 3)
                            test = test && ($0.scoped(on: c, cd)["id"] == 4)
                            return test
                    }
                    XCTAssertEqual(
                        self.sql(db, request),
                        "SELECT \"a\".* " +
                            "FROM \"a\" " +
                            "LEFT JOIN \"b\" ON (\"b\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d0\" ON (\"d0\".\"bID\" = \"b\".\"id\") " +
                            "LEFT JOIN \"c\" ON (\"c\".\"aID\" = \"a\".\"id\") " +
                            "LEFT JOIN \"d\" \"d1\" ON (\"d1\".\"cID\" = \"c\".\"id\") " +
                        "WHERE (((((\"a\".\"id\" = 0) AND (\"b\".\"id\" = 1)) AND (\"d0\".\"id\" = 2)) AND (\"c\".\"id\" = 3)) AND (\"d1\".\"id\" = 4))")
                }
            }
        }
    }
}
