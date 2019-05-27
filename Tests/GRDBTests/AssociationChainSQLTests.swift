import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A -> B <- C -> D
private struct A: TableRecord, EncodableRecord {
    static let databaseTableName = "a"
    static let b = belongsTo(B.self)
    static let c = hasOne(C.self, through: b, using: B.c)
    func encode(to container: inout PersistenceContainer) {
        container["bid"] = 1
    }
}

private struct B: TableRecord {
    static let c = hasOne(C.self)
    static let d = hasOne(D.self, through: c, using: C.d)
    static let databaseTableName = "b"
}

private struct C: TableRecord {
    static let databaseTableName = "c"
    static let b = belongsTo(B.self)
    static let d = belongsTo(D.self)
}

private struct D: TableRecord {
    static let databaseTableName = "d"
}

/// Test SQL generation
class AssociationChainSQLTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "b") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "d") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "a") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid", .integer).references("b")
            }
            try db.create(table: "c") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid", .integer).references("b")
                t.column("did", .integer).references("d")
            }
        }
    }
    
    func testChainOfTwoRequestForIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Direct, Direct
            try assertEqualSQL(db, A().request(for: A.b.including(required: B.c)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                WHERE "b"."id" = 1
                """)
            try assertEqualSQL(db, A().request(for: A.b.including(optional: B.c)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                WHERE "b"."id" = 1
                """)
            
            // Direct, Through
            try assertEqualSQL(db, A().request(for: A.b.including(required: B.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did" \
                WHERE "b"."id" = 1
                """)
            try assertEqualSQL(db, A().request(for: A.b.including(optional: B.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did" \
                WHERE "b"."id" = 1
                """)
            
            // Through, Through
            try assertEqualSQL(db, A().request(for: A.c.including(required: C.d)), """
                SELECT "c".*, "d".* \
                FROM "c" \
                JOIN "d" ON "d"."id" = "c"."did" \
                JOIN "b" ON ("b"."id" = "c"."bid") AND ("b"."id" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.c.including(optional: C.d)), """
                SELECT "c".*, "d".* \
                FROM "c" \
                LEFT JOIN "d" ON "d"."id" = "c"."did" \
                JOIN "b" ON ("b"."id" = "c"."bid") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testChainOfTwoIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c)), "TODO")
            try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(required: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.including(optional: B.c.including(required: C.d)), "TODO")
            try assertEqualSQL(db, B.including(optional: B.c.including(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfTwoIncludingIncludingIncludingSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c).including(required: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c).including(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c).including(required: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c).including(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c).including(required: B.c)), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c).including(optional: B.c)), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c).including(required: B.c)), "TODO")
            try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c).including(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(required: C.d).including(required: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(required: C.d).including(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(optional: C.d).including(required: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(optional: C.d).including(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.including(optional: B.c.including(required: C.d).including(required: C.d)), "TODO")
            // try assertEqualSQL(db, B.including(optional: B.c.including(required: C.d).including(optional: C.d)), "TODO")
            // try assertEqualSQL(db, B.including(optional: B.c.including(optional: C.d).including(required: C.d)), "TODO")
            try assertEqualSQL(db, B.including(optional: B.c.including(optional: C.d).including(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }

    func testChainOfTwoIncludingIncludingJoiningSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c).joining(required: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c).joining(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c).joining(required: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c).joining(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c).joining(required: B.c)), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c).joining(optional: B.c)), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c).joining(required: B.c)), "TODO")
            try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c).joining(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(required: C.d).joining(required: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(required: C.d).joining(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(optional: C.d).joining(required: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.including(optional: C.d).joining(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.including(optional: B.c.including(required: C.d).joining(required: C.d)), "TODO")
            // try assertEqualSQL(db, B.including(optional: B.c.including(required: C.d).joining(optional: C.d)), "TODO")
            // try assertEqualSQL(db, B.including(optional: B.c.including(optional: C.d).joining(required: C.d)), "TODO")
            try assertEqualSQL(db, B.including(optional: B.c.including(optional: C.d).joining(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfTwoRequestForJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Direct, Direct
            try assertEqualSQL(db, A().request(for: A.b.joining(required: B.c)), """
                SELECT "b".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                WHERE "b"."id" = 1
                """)
            try assertEqualSQL(db, A().request(for: A.b.joining(optional: B.c)), """
                SELECT "b".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                WHERE "b"."id" = 1
                """)
            
            // Direct, Through
            try assertEqualSQL(db, A().request(for: A.b.joining(required: B.d)), """
                SELECT "b".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did" \
                WHERE "b"."id" = 1
                """)
            try assertEqualSQL(db, A().request(for: A.b.joining(optional: B.d)), """
                SELECT "b".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did" \
                WHERE "b"."id" = 1
                """)
            
            // Through, Through
            try assertEqualSQL(db, A().request(for: A.c.joining(required: C.d)), """
                SELECT "c".* \
                FROM "c" \
                JOIN "d" ON "d"."id" = "c"."did" \
                JOIN "b" ON ("b"."id" = "c"."bid") AND ("b"."id" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.c.joining(optional: C.d)), """
                SELECT "c".* \
                FROM "c" \
                LEFT JOIN "d" ON "d"."id" = "c"."did" \
                JOIN "b" ON ("b"."id" = "c"."bid") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testChainOfTwoIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c)), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c)), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c)), "")
            try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c)), """
                SELECT "a".*, "b".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(required: C.d)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(optional: C.d)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.including(optional: B.c.joining(required: C.d)), "TODO")
            try assertEqualSQL(db, B.including(optional: B.c.joining(optional: C.d)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfTwoIncludingJoiningIncludingSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c).including(required: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c).including(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c).including(required: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c).including(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c).including(required: B.c)), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c).including(optional: B.c)), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c).including(required: B.c)), "TODO")
            try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c).including(optional: B.c)), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(required: C.d).including(required: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(required: C.d).including(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(optional: C.d).including(required: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(optional: C.d).including(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.including(optional: B.c.joining(required: C.d).including(required: C.d)), "TODO")
            // try assertEqualSQL(db, B.including(optional: B.c.joining(required: C.d).including(optional: C.d)), "TODO")
            // try assertEqualSQL(db, B.including(optional: B.c.joining(optional: C.d).including(required: C.d)), "TODO")
            try assertEqualSQL(db, B.including(optional: B.c.joining(optional: C.d).including(optional: C.d)), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }

    func testChainOfTwoIncludingJoiningJoiningSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c).joining(required: B.c)), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c).joining(optional: B.c)), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c).joining(required: B.c)), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c).joining(optional: B.c)), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c).joining(required: B.c)), "")
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c).joining(optional: B.c)), "")
            // try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c).joining(required: B.c)), "")
            try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c).joining(optional: B.c)), """
                SELECT "a".*, "b".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(required: C.d).joining(required: C.d)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(required: C.d).joining(optional: C.d)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(optional: C.d).joining(required: C.d)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.including(required: B.c.joining(optional: C.d).joining(optional: C.d)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.including(optional: B.c.joining(required: C.d).joining(required: C.d)), "TODO")
            // try assertEqualSQL(db, B.including(optional: B.c.joining(required: C.d).joining(optional: C.d)), "TODO")
            // try assertEqualSQL(db, B.including(optional: B.c.joining(optional: C.d).joining(required: C.d)), "TODO")
            try assertEqualSQL(db, B.including(optional: B.c.joining(optional: C.d).joining(optional: C.d)), """
                SELECT "b".*, "c".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfTwoJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c)), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(required: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.joining(optional: B.c.including(required: C.d)), "TODO")
            try assertEqualSQL(db, B.joining(optional: B.c.including(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfTwoJoiningIncludingIncludingSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c).including(required: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c).including(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c).including(required: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c).including(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c).including(required: B.c)), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c).including(optional: B.c)), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c).including(required: B.c)), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c).including(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(required: C.d).including(required: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(required: C.d).including(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(optional: C.d).including(required: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(optional: C.d).including(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.joining(optional: B.c.including(required: C.d).including(required: C.d)), "TODO")
            // try assertEqualSQL(db, B.joining(optional: B.c.including(required: C.d).including(optional: C.d)), "TODO")
            // try assertEqualSQL(db, B.joining(optional: B.c.including(optional: C.d).including(required: C.d)), "TODO")
            try assertEqualSQL(db, B.joining(optional: B.c.including(optional: C.d).including(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfTwoJoiningIncludingJoiningSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c).joining(required: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c).joining(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c).joining(required: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c).joining(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c).joining(required: B.c)), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c).joining(optional: B.c)), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c).joining(required: B.c)), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c).joining(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(required: C.d).joining(required: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(required: C.d).joining(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(optional: C.d).joining(required: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.including(optional: C.d).joining(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.joining(optional: B.c.including(required: C.d).joining(required: C.d)), "TODO")
            // try assertEqualSQL(db, B.joining(optional: B.c.including(required: C.d).joining(optional: C.d)), "TODO")
            // try assertEqualSQL(db, B.joining(optional: B.c.including(optional: C.d).joining(required: C.d)), "TODO")
            try assertEqualSQL(db, B.joining(optional: B.c.including(optional: C.d).joining(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }

    func testChainOfTwoJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c)), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c)), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c)), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c)), """
                SELECT "a".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(required: C.d)), """
                SELECT "b".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(optional: C.d)), """
                SELECT "b".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.joining(optional: B.c.joining(required: C.d)), "TODO")
            try assertEqualSQL(db, B.joining(optional: B.c.joining(optional: C.d)), """
                SELECT "b".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfTwoJoiningJoiningIncludingSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c).including(required: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c).including(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c).including(required: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c).including(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c).including(required: B.c)), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c).including(optional: B.c)), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c).including(required: B.c)), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c).including(optional: B.c)), """
                SELECT "a".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(required: C.d).including(required: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(required: C.d).including(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(optional: C.d).including(required: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(optional: C.d).including(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.joining(optional: B.c.joining(required: C.d).including(required: C.d)), "TODO")
            // try assertEqualSQL(db, B.joining(optional: B.c.joining(required: C.d).including(optional: C.d)), "TODO")
            // try assertEqualSQL(db, B.joining(optional: B.c.joining(optional: C.d).including(required: C.d)), "TODO")
            try assertEqualSQL(db, B.joining(optional: B.c.joining(optional: C.d).including(optional: C.d)), """
                SELECT "b".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }

    func testChainOfTwoJoiningJoiningJoiningSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c).joining(required: B.c)), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c).joining(optional: B.c)), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c).joining(required: B.c)), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c).joining(optional: B.c)), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c).joining(required: B.c)), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c).joining(optional: B.c)), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c).joining(required: B.c)), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c).joining(optional: B.c)), """
                SELECT "a".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(required: C.d).joining(required: C.d)), """
                SELECT "b".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(required: C.d).joining(optional: C.d)), """
                SELECT "b".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(optional: C.d).joining(required: C.d)), """
                SELECT "b".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, B.joining(required: B.c.joining(optional: C.d).joining(optional: C.d)), """
                SELECT "b".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, B.joining(optional: B.c.joining(required: C.d).joining(required: C.d)), "TODO")
            // try assertEqualSQL(db, B.joining(optional: B.c.joining(required: C.d).joining(optional: C.d)), "TODO")
            // try assertEqualSQL(db, B.joining(optional: B.c.joining(optional: C.d).joining(required: C.d)), "TODO")
            try assertEqualSQL(db, B.joining(optional: B.c.joining(optional: C.d).joining(optional: C.d)), """
                SELECT "b".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfThreeRequestForIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A().request(for: A.b.including(required: B.c.including(required: C.d))), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did" \
                WHERE "b"."id" = 1
                """)
            try assertEqualSQL(db, A().request(for: A.b.including(required: B.c.including(optional: C.d))), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did" \
                WHERE "b"."id" = 1
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A().request(for: A.b.including(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A().request(for: A.b.including(optional: B.c.including(optional: C.d))), """
                SELECT "b".*, "c".*, "d".* \
                FROM "b" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did" \
                WHERE "b"."id" = 1
                """)
        }
    }
    
    func testChainOfThreeIncludingIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c.including(required: C.d))), """
                SELECT "a".*, "b".*, "c".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c.including(optional: C.d))), """
                SELECT "a".*, "b".*, "c".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c.including(optional: C.d))), """
                SELECT "a".*, "b".*, "c".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c.including(required: C.d))), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c.including(optional: C.d))), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c.including(optional: C.d))), """
                SELECT "a".*, "b".*, "c".*, "d".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfThreeIncludingIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c.joining(required: C.d))), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, A.including(required: A.b.including(required: B.c.joining(optional: C.d))), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c.joining(required: C.d))), "TODO")
            try assertEqualSQL(db, A.including(required: A.b.including(optional: B.c.joining(optional: C.d))), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c.joining(required: C.d))), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.including(required: B.c.joining(optional: C.d))), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c.joining(required: C.d))), "TODO")
            try assertEqualSQL(db, A.including(optional: A.b.including(optional: B.c.joining(optional: C.d))), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfThreeIncludingJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c.including(required: C.d))), """
                SELECT "a".*, "b".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c.including(optional: C.d))), """
                SELECT "a".*, "b".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c.including(optional: C.d))), """
                SELECT "a".*, "b".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c.including(required: C.d))), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c.including(optional: C.d))), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c.including(optional: C.d))), """
                SELECT "a".*, "b".*, "d".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfThreeIncludingJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c.joining(required: C.d))), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, A.including(required: A.b.joining(required: B.c.joining(optional: C.d))), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c.joining(required: C.d))), "TODO")
            try assertEqualSQL(db, A.including(required: A.b.joining(optional: B.c.joining(optional: C.d))), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c.joining(required: C.d))), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.joining(required: B.c.joining(optional: C.d))), "TODO")
            // try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c.joining(required: C.d))), "TODO")
            try assertEqualSQL(db, A.including(optional: A.b.joining(optional: B.c.joining(optional: C.d))), """
                SELECT "a".*, "b".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfThreeJoiningIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c.including(required: C.d))), """
                SELECT "a".*, "c".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c.including(optional: C.d))), """
                SELECT "a".*, "c".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c.including(optional: C.d))), """
                SELECT "a".*, "c".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c.including(required: C.d))), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c.including(optional: C.d))), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c.including(optional: C.d))), """
                SELECT "a".*, "c".*, "d".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfThreeJoiningIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c.joining(required: C.d))), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.including(required: B.c.joining(optional: C.d))), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c.joining(required: C.d))), "TODO")
            try assertEqualSQL(db, A.joining(required: A.b.including(optional: B.c.joining(optional: C.d))), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c.joining(required: C.d))), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.including(required: B.c.joining(optional: C.d))), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c.joining(required: C.d))), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.including(optional: B.c.joining(optional: C.d))), """
                SELECT "a".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfThreeJoiningJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c.including(required: C.d))), """
                SELECT "a".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c.including(optional: C.d))), """
                SELECT "a".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c.including(optional: C.d))), """
                SELECT "a".*, "d".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c.including(required: C.d))), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c.including(optional: C.d))), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c.including(required: C.d))), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c.including(optional: C.d))), """
                SELECT "a".*, "d".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
    
    func testChainOfThreeJoiningJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c.joining(required: C.d))), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                JOIN "d" ON "d"."id" = "c"."did"
                """)
            try assertEqualSQL(db, A.joining(required: A.b.joining(required: B.c.joining(optional: C.d))), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c.joining(required: C.d))), "TODO")
            try assertEqualSQL(db, A.joining(required: A.b.joining(optional: B.c.joining(optional: C.d))), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
            // TODO: chainOptionalRequired
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c.joining(required: C.d))), "TODO")
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(required: B.c.joining(optional: C.d))), "TODO)
            // try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c.joining(required: C.d))), "TODO")
            try assertEqualSQL(db, A.joining(optional: A.b.joining(optional: B.c.joining(optional: C.d))), """
                SELECT "a".* \
                FROM "a" \
                LEFT JOIN "b" ON "b"."id" = "a"."bid" \
                LEFT JOIN "c" ON "c"."bid" = "b"."id" \
                LEFT JOIN "d" ON "d"."id" = "c"."did"
                """)
        }
    }
}
