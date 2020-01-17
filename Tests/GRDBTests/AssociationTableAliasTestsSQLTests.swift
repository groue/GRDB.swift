import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A -> A
// A -> B1
// A -> B2
private struct A : TableRecord {
    static let databaseTableName = "a"
    static let parent = belongsTo(A.self)
    static let child = hasOne(A.self)
    static let b1 = belongsTo(B.self, key: "b1", using: ForeignKey(["bid1"]))
    static let b2 = belongsTo(B.self, key: "b2", using: ForeignKey(["bid2"]))
}
private struct B : TableRecord {
    static let databaseTableName = "b"
    static let a1 = hasOne(A.self, key: "a1", using: ForeignKey(["bid1"]))
    static let a2 = hasOne(A.self, key: "a1", using: ForeignKey(["bid2"]))
}

/// Tests for table name conflicts, recursive associations,
/// user-defined table aliases, and expressions that involve several tables.
class AssociationTableAliasTestsSQLTests : GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "b") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "a") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid1", .integer).references("b")
                t.column("bid2", .integer).references("b")
                t.column("parentId", .integer).references("a")
                t.column("name", .text)
            }
        }
    }
    
    func testTableAliasBasics() throws {
        // A table reference qualifies all unqualified selectables, expressions, and orderings
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let alias = TableAlias()
                let name = Column("name")
                let condition = name != nil && alias[name] == "foo"
                
                let expectedSQL = """
                    SELECT "name" \
                    FROM "a" \
                    WHERE ("id" = 1) AND ("name" IS NOT NULL) AND ("name" = 'foo') \
                    GROUP BY "name" \
                    HAVING "name" \
                    ORDER BY "name"
                    """
                
                do {
                    let request = A
                        .aliased(alias)
                        .select(name)
                        .filter(key: 1)
                        .filter(condition)
                        .group(name)
                        .having(name)
                        .order(name)
                    try assertEqualSQL(db, request, expectedSQL)
                }
                do {
                    let request = A
                        .select(name)
                        .filter(key: 1)
                        .filter(condition)
                        .group(name)
                        .having(name)
                        .order(name)
                        .aliased(alias)
                    try assertEqualSQL(db, request, expectedSQL)
                }
            }
            do {
                let alias = TableAlias(name: "customA")
                let name = Column("name")
                let condition = name != nil && alias[name] == "foo"
                
                let expectedSQL = """
                    SELECT "customA"."name" \
                    FROM "a" "customA" \
                    WHERE ("customA"."id" = 1) AND ("customA"."name" IS NOT NULL) AND ("customA"."name" = 'foo') \
                    GROUP BY "customA"."name" \
                    HAVING "customA"."name" \
                    ORDER BY "customA"."name"
                    """
                
                do {
                    let request = A
                        .aliased(alias)
                        .select(name)
                        .filter(key: 1)
                        .filter(condition)
                        .group(name)
                        .having(name)
                        .order(name)
                    try assertEqualSQL(db, request, expectedSQL)
                }
                do {
                    let request = A
                        .select(name)
                        .filter(key: 1)
                        .filter(condition)
                        .group(name)
                        .having(name)
                        .order(name)
                        .aliased(alias)
                    try assertEqualSQL(db, request, expectedSQL)
                }
            }
        }
    }
    
    func testRecursiveRelationDepth1() throws {
        // A.include(A.parent)
        // A.include(A.child)
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.parent), """
                SELECT "a1".*, "a2".* \
                FROM "a" "a1" \
                JOIN "a" "a2" ON "a2"."id" = "a1"."parentId"
                """)
            try assertEqualSQL(db, A.including(required: A.child), """
                SELECT "a1".*, "a2".* \
                FROM "a" "a1" \
                JOIN "a" "a2" ON "a2"."parentId" = "a1"."id"
                """)
        }
    }

    func testRecursiveRelationDepth2() throws {
        // A.include(B1).include(A)
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = A
                .including(required: A.b1
                    .including(required: B.a2))
            try assertEqualSQL(db, request, """
                SELECT "a1".*, "b".*, "a2".* \
                FROM "a" "a1" \
                JOIN "b" ON "b"."id" = "a1"."bid1" \
                JOIN "a" "a2" ON "a2"."bid2" = "b"."id"
                """)
        }
    }

    func testMultipleForeignKeys() throws {
        // A
        //   .include(B1)
        //   .include(B2)
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = A
                .including(required: A.b1)
                .including(required: A.b2)
            try assertEqualSQL(db, request, """
                SELECT "a".*, "b1".*, "b2".* \
                FROM "a" \
                JOIN "b" "b1" ON "b1"."id" = "a"."bid1" \
                JOIN "b" "b2" ON "b2"."id" = "a"."bid2"
                """)
        }
    }

    func testRecursiveThroughMultipleForeignKeys() throws {
        // A
        //   .include(B1.include(A))
        //   .include(B2.include(A))
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = A
                .including(required: A.b1
                    .including(required: B.a2))
                .including(required: A.b2
                    .including(required: B.a1))
            try assertEqualSQL(db, request, """
                SELECT "a1".*, "b1".*, "a2".*, "b2".*, "a3".* \
                FROM "a" "a1" \
                JOIN "b" "b1" ON "b1"."id" = "a1"."bid1" \
                JOIN "a" "a2" ON "a2"."bid2" = "b1"."id" \
                JOIN "b" "b2" ON "b2"."id" = "a1"."bid2" \
                JOIN "a" "a3" ON "a3"."bid1" = "b2"."id"
                """)
        }
    }
    
    func testUserDefinedAlias() throws {
        // A
        //   .aliased("customA")
        //   .include(B1.aliased("customB"))
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let aAlias1 = TableAlias(name: "customA1")  // On TableMapping and QueryInterfaceRequest
            let bAlias = TableAlias(name: "customB")    // On BelongsToAssociation
            let aAlias2 = TableAlias(name: "customA2")  // On HasOneAssociation
            
            let expectedSQL = """
                SELECT "customA1".*, "customB".*, "customA2".* \
                FROM "a" "customA1" \
                JOIN "b" "customB" ON "customB"."id" = "customA1"."bid1" \
                JOIN "a" "customA2" ON "customA2"."bid2" = "customB"."id"
                """
            
            do {
                // Alias first
                let request = A
                    .aliased(aAlias1)
                    .including(required: A.b1
                        .aliased(bAlias)
                        .including(required: B.a2
                            .aliased(aAlias2)))
                try assertEqualSQL(db, request, expectedSQL)
            }
            
            do {
                // Alias last
                let request = A
                    .including(required: A.b1
                        .including(required: B.a2
                            .aliased(aAlias2))
                        .aliased(bAlias))
                    .aliased(aAlias1)
                try assertEqualSQL(db, request, expectedSQL)
            }
        }
    }

    func testUserInducedNameConflict() throws {
        // A.include(B1.aliased("a"))
        // A.aliased("b").include(B1)
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let bAlias = TableAlias(name: A.databaseTableName.lowercased())
                let request = A.including(required: A.b1.aliased(bAlias))
                try assertEqualSQL(db, request, """
                    SELECT "a1".*, "a".* \
                    FROM "a" "a1" \
                    JOIN "b" "a" ON "a"."id" = "a1"."bid1"
                    """)
            }
            do {
                let bAlias = TableAlias(name: A.databaseTableName.uppercased())
                let request = A.including(required: A.b1.aliased(bAlias))
                try assertEqualSQL(db, request, """
                    SELECT "a1".*, "A".* \
                    FROM "a" "a1" \
                    JOIN "b" "A" ON "A"."id" = "a1"."bid1"
                    """)
            }
            do {
                let aAlias = TableAlias(name: B.databaseTableName.lowercased())
                let request = A.aliased(aAlias).including(required: A.b1)
                try assertEqualSQL(db, request, """
                    SELECT "b".*, "b1".* \
                    FROM "a" "b" \
                    JOIN "b" "b1" ON "b1"."id" = "b"."bid1"
                    """)
            }
            do {
                let aAlias = TableAlias(name: B.databaseTableName.uppercased())
                let request = A.aliased(aAlias).including(required: A.b1)
                try assertEqualSQL(db, request, """
                    SELECT "B".*, "b1".* \
                    FROM "a" "B" \
                    JOIN "b" "b1" ON "b1"."id" = "B"."bid1"
                    """)
            }
        }
    }
    
    func testCrossTableExpressions() throws {
        // A
        //   .include(B1.include(A))
        //   .include(B2.include(A))
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let rootA = TableAlias()
            let A1 = TableAlias()
            let A2 = TableAlias()
            let name = Column("name")
            
            let condition = name != nil && rootA[name] > A1[name] && A2[name] == "foo"
            
            let expectedSQL = """
                SELECT "a1".*, "b1".*, "a2".*, "b2".*, "a3".* \
                FROM "a" "a1" \
                JOIN "b" "b1" ON "b1"."id" = "a1"."bid1" \
                JOIN "a" "a2" ON "a2"."bid2" = "b1"."id" \
                JOIN "b" "b2" ON "b2"."id" = "a1"."bid2" \
                JOIN "a" "a3" ON "a3"."bid1" = "b2"."id" \
                WHERE ("a1"."name" IS NOT NULL) AND ("a1"."name" > "a3"."name") AND ("a2"."name" = 'foo')
                """
            
            do {
                // Filter first
                let request = A
                    .filter(condition)
                    .aliased(rootA)
                    .including(required: A.b1
                        .including(required: B.a2.aliased(A2)))
                    .including(required: A.b2
                        .including(required: B.a1.aliased(A1)))
                try assertEqualSQL(db, request, expectedSQL)
            }
            
            do {
                // Filter last
                let request = A
                    .aliased(rootA)
                    .including(required: A.b1
                        .including(required: B.a2.aliased(A2)))
                    .including(required: A.b2
                        .including(required: B.a1.aliased(A1)))
                    .filter(condition)
                try assertEqualSQL(db, request, expectedSQL)
            }
        }
    }
    
    func testAssociationRewrite() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let request: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias()
                    let name = Column("name")
                    return A
                        .joining(required: A.parent.aliased(parentAlias))
                        .filter(parentAlias[name] == "foo")
                }()
                
                let request2: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias()
                    let name = Column("name")
                    return request
                        .joining(optional: A.parent.aliased(parentAlias))
                        .order(parentAlias[name])
                }()
                
                let request3 = request2.including(optional: A.parent)
                
                try assertEqualSQL(db, request3, """
                    SELECT "a1".*, "a2".* \
                    FROM "a" "a1" \
                    JOIN "a" "a2" ON "a2"."id" = "a1"."parentId" \
                    WHERE "a2"."name" = 'foo' \
                    ORDER BY "a2"."name"
                    """)
            }
            do {
                let request: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias(name: "parent")
                    let name = Column("name")
                    return A
                        .joining(required: A.parent.aliased(parentAlias))
                        .filter(parentAlias[name] == "foo")
                }()
                
                let request2: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias()
                    let name = Column("name")
                    return request
                        .joining(optional: A.parent.aliased(parentAlias))
                        .order(parentAlias[name])
                }()
                
                let request3 = request2.including(optional: A.parent)
                
                try assertEqualSQL(db, request3, """
                    SELECT "a".*, "parent".* \
                    FROM "a" \
                    JOIN "a" "parent" ON "parent"."id" = "a"."parentId" \
                    WHERE "parent"."name" = 'foo' \
                    ORDER BY "parent"."name"
                    """)
            }
            do {
                let request: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias()
                    let name = Column("name")
                    return A
                        .joining(required: A.parent.aliased(parentAlias))
                        .filter(parentAlias[name] == "foo")
                }()
                
                let request2: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias(name: "parent")
                    let name = Column("name")
                    return request
                        .joining(optional: A.parent.aliased(parentAlias))
                        .order(parentAlias[name])
                }()
                
                let request3 = request2.including(optional: A.parent)
                
                try assertEqualSQL(db, request3, """
                    SELECT "a".*, "parent".* \
                    FROM "a" \
                    JOIN "a" "parent" ON "parent"."id" = "a"."parentId" \
                    WHERE "parent"."name" = 'foo' \
                    ORDER BY "parent"."name"
                    """)
            }
            do {
                let request: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias(name: "parent")
                    let name = Column("name")
                    return A
                        .joining(required: A.parent.aliased(parentAlias))
                        .filter(parentAlias[name] == "foo")
                }()
                
                let request2: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias(name: "parent")
                    let name = Column("name")
                    return request
                        .joining(optional: A.parent.aliased(parentAlias))
                        .order(parentAlias[name])
                }()
                
                let request3 = request2.including(optional: A.parent)
                
                try assertEqualSQL(db, request3, """
                    SELECT "a".*, "parent".* \
                    FROM "a" \
                    JOIN "a" "parent" ON "parent"."id" = "a"."parentId" \
                    WHERE "parent"."name" = 'foo' \
                    ORDER BY "parent"."name"
                    """)
            }
            do {
                let request: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias()
                    let name = Column("name")
                    return A
                        .joining(required: A.parent.aliased(parentAlias))
                        .filter(parentAlias[name] == "foo")
                }()
                
                let request2: QueryInterfaceRequest<A> = {
                    let parentAlias = TableAlias()
                    let name = Column("name")
                    return request
                        .joining(optional: A.parent.aliased(parentAlias))
                        .order(parentAlias[name])
                }()
                
                let parentAlias = TableAlias(name: "parent")
                let request3 = request2.including(optional: A.parent.aliased(parentAlias))
                
                try assertEqualSQL(db, request3, """
                    SELECT "a".*, "parent".* \
                    FROM "a" \
                    JOIN "a" "parent" ON "parent"."id" = "a"."parentId" \
                    WHERE "parent"."name" = 'foo' \
                    ORDER BY "parent"."name"
                    """)
            }
        }
    }
}
