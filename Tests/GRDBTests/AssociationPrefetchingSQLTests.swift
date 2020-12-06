import XCTest
import GRDB

private struct A: TableRecord { }
private struct B: TableRecord { }
private struct C: TableRecord { }
private struct D: TableRecord { }

class AssociationPrefetchingSQLTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        // A.hasMany(B)
        // A.hasMany(C)
        // B.belongsTo(A)
        // C.belongsTo(A)
        // C.hasMany(D)
        // D.belongsTo(C)
        try dbWriter.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("cola1")
                t.column("cola2", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("colb1")
                t.column("colb2", .integer).references("a")
                t.column("colb3", .text)
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("colc1")
                t.column("colc2", .integer).references("a")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("cold1")
                t.column("cold2", .integer).references("c")
                t.column("cold3", .text)
            }
            try db.execute(
                sql: """
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    """,
                arguments: [
                    1, "a1",
                    2, "a2",
                    3, "a3",
                    4, 1, "b1",
                    5, 1, "b2",
                    6, 2, "b3",
                    14, nil, "b4",
                    7, 1,
                    8, 2,
                    9, 2,
                    10, 7, "d1",
                    11, 8, "d2",
                    12, 8, "d3",
                    13, 9, "d4",
                ])
        }
    }
    
    func testIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(B.self)
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT *, "colb2" AS "grdb_colb2" \
                    FROM "b" \
                    WHERE "colb2" IN (1, 2, 3) \
                    ORDER BY "colb1"
                    """])
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .none()
                    .including(all: A
                        .hasMany(B.self)
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM \"a\" WHERE 0 ORDER BY \"cola1\"
                    """])
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(B.self)
                        .filter(Column("colb1") == 4)
                        .orderByPrimaryKey()
                        .forKey("bs1"))
                    .including(all: A
                        .hasMany(B.self)
                        .filter(Column("colb1") != 4)
                        .orderByPrimaryKey()
                        .forKey("bs2"))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" \
                    WHERE "cola1" <> 3 \
                    ORDER BY "cola1"
                    """,
                    """
                    SELECT *, "colb2" AS "grdb_colb2" \
                    FROM "b" \
                    WHERE ("colb1" = 4) AND ("colb2" IN (1, 2)) \
                    ORDER BY "colb1"
                    """,
                    """
                    SELECT *, "colb2" AS "grdb_colb2" \
                    FROM "b" \
                    WHERE ("colb1" <> 4) AND ("colb2" IN (1, 2)) \
                    ORDER BY "colb1"
                    """])
            }
        }
    }
    
    func testIncludingAllHasManyWithCompoundForeignKey() throws {
        // We can use the CTE technique
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "parent") { t in
                t.column("parentA", .text)
                t.column("parentB", .text)
                t.primaryKey(["parentA", "parentB"])
            }
            try db.create(table: "child") { t in
                t.column("pA", .text)
                t.column("pB", .text)
                t.column("name", .text)
                t.foreignKey(["pA", "pB"], references: "parent")
            }
            try db.execute(sql: """
                INSERT INTO parent (parentA, parentB) VALUES ('foo', 'bar');
                INSERT INTO parent (parentA, parentB) VALUES ('baz', 'qux');
                INSERT INTO child (pA, pB, name) VALUES ('foo', 'bar', 'foobar1');
                INSERT INTO child (pA, pB, name) VALUES ('foo', 'bar', 'foobar2');
                INSERT INTO child (pA, pB, name) VALUES ('baz', 'qux', 'bazqux1');
                """)
            
            struct Parent: TableRecord { }
            struct Child: TableRecord { }
            
            // Plain request
            do {
                let request = Parent
                    .including(all: Parent
                        .hasMany(Child.self))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "parent" ORDER BY "parentA", "parentB"
                    """,
                    """
                    WITH "grdb_base" AS (SELECT "parentA", "parentB" FROM "parent") \
                    SELECT *, "pA" AS "grdb_pA", "pB" AS "grdb_pB" \
                    FROM "child" WHERE ("pA", "pB") IN "grdb_base"
                    """])
            }
            
            // Request with avoided prefetch
            do {
                let request = Parent
                    .none()
                    .including(all: Parent
                        .hasMany(Child.self))
                    .orderByPrimaryKey()

                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "parent" WHERE 0 ORDER BY "parentA", "parentB"
                    """])
            }
            
            // Request with filters
            do {
                let request = Parent
                    .including(all: Parent
                        .hasMany(Child.self)
                        .filter(Column("name") == "foo"))
                    .filter(Column("parentA") == "foo")
                    .orderByPrimaryKey()

                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "parent" WHERE "parentA" = 'foo' ORDER BY "parentA", "parentB"
                    """,
                    """
                    WITH "grdb_base" AS (SELECT "parentA", "parentB" FROM "parent" WHERE "parentA" = 'foo') \
                    SELECT *, "pA" AS "grdb_pA", "pB" AS "grdb_pB" \
                    FROM "child" \
                    WHERE ("name" = 'foo') AND (("pA", "pB") IN "grdb_base")
                    """])
            }
        }
    }
    
    func testIncludingAllHasManyIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT *, "colc2" AS "grdb_colc2" \
                    FROM "c" \
                    WHERE "colc2" IN (1, 2, 3) \
                    ORDER BY "colc1"
                    """,
                    """
                    SELECT *, "cold2" AS "grdb_cold2" \
                    FROM "d" \
                    WHERE "cold2" IN (7, 8, 9) \
                    ORDER BY "cold1"
                    """])
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .none()
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT *, "colc2" AS "grdb_colc2" \
                    FROM "c" \
                    WHERE 0 AND ("colc2" IN (1, 2, 3)) \
                    ORDER BY "colc1"
                    """])
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") > 7)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .orderByPrimaryKey()
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .orderByPrimaryKey()
                        .forKey("cs2"))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * \
                    FROM "a" \
                    WHERE "cola1" <> 3 \
                    ORDER BY "cola1"
                    """,
                    """
                    SELECT *, "colc2" AS "grdb_colc2" \
                    FROM "c" \
                    WHERE ("colc1" > 7) AND ("colc2" IN (1, 2)) \
                    ORDER BY "colc1"
                    """,
                    """
                    SELECT *, "cold2" AS "grdb_cold2" \
                    FROM "d" \
                    WHERE ("cold1" = 11) AND ("cold2" IN (8, 9)) \
                    ORDER BY "cold1"
                    """,
                    """
                    SELECT *, "cold2" AS "grdb_cold2" \
                    FROM "d" \
                    WHERE ("cold1" <> 11) AND ("cold2" IN (8, 9)) \
                    ORDER BY "cold1"
                    """,
                    """
                    SELECT *, "colc2" AS "grdb_colc2" \
                    FROM "c" \
                    WHERE ("colc1" < 9) AND ("colc2" IN (1, 2)) \
                    ORDER BY "colc1"
                    """,
                    """
                    SELECT *, "cold2" AS "grdb_cold2" \
                    FROM "d" \
                    WHERE ("cold1" = 11) AND ("cold2" IN (7, 8)) \
                    ORDER BY "cold1"
                    """,
                    """
                    SELECT *, "cold2" AS "grdb_cold2" \
                    FROM "d" \
                    WHERE ("cold1" <> 11) AND ("cold2" IN (7, 8)) \
                    ORDER BY "cold1"
                    """])
            }
        }
    }
    
    func testIncludingAllHasManyIncludingAllHasManyWithCompoundForeignKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "parent") { t in
                t.column("parentA", .text)
                t.column("parentB", .text)
                t.column("name", .text)
                t.primaryKey(["parentA", "parentB"])
            }
            try db.create(table: "child") { t in
                t.column("childA", .text)
                t.column("childB", .text)
                t.column("pA", .text)
                t.column("pB", .text)
                t.column("name", .text)
                t.primaryKey(["childA", "childB"])
                t.foreignKey(["pA", "pB"], references: "parent")
            }
            try db.create(table: "grandchild") { t in
                t.column("cA", .text)
                t.column("cB", .text)
                t.column("name", .text)
                t.foreignKey(["cA", "cB"], references: "child")
            }
            try db.execute(sql: """
                INSERT INTO parent (parentA, parentB, name) VALUES ('foo', 'bar', 'foo');
                INSERT INTO parent (parentA, parentB, name) VALUES ('baz', 'qux', 'foo');
                INSERT INTO child (childA, childB, pA, pB, name) VALUES ('a', 'b', 'foo', 'bar', 'blue');
                INSERT INTO child (childA, childB, pA, pB, name) VALUES ('c', 'd', 'foo', 'bar', 'pink');
                INSERT INTO child (childA, childB, pA, pB, name) VALUES ('e', 'f', 'baz', 'qux', 'blue');
                INSERT INTO grandchild (cA, cB, name) VALUES ('a', 'b', 'dog');
                INSERT INTO grandchild (cA, cB, name) VALUES ('a', 'b', 'cat');
                INSERT INTO grandchild (cA, cB, name) VALUES ('c', 'd', 'cat');
                INSERT INTO grandchild (cA, cB, name) VALUES ('e', 'f', 'dog');
                """)
            
            struct Parent: TableRecord { }
            struct Child: TableRecord { }
            struct GrandChild: TableRecord { }
            
            // Plain request
            do {
                let request = Parent
                    .including(all: Parent.hasMany(Child.self)
                                .including(all: Child.hasMany(GrandChild.self)))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "parent" ORDER BY "parentA", "parentB"
                    """,
                    """
                    WITH "grdb_base" AS (SELECT "parentA", "parentB" FROM "parent") \
                    SELECT *, "pA" AS "grdb_pA", "pB" AS "grdb_pB" \
                    FROM "child" WHERE ("pA", "pB") IN "grdb_base"
                    """,
                    """
                    WITH "grdb_base" AS (\
                    WITH "grdb_base" AS (SELECT "parentA", "parentB" FROM "parent") \
                    SELECT "childA", "childB" FROM "child" \
                    WHERE ("pA", "pB") IN "grdb_base"\
                    ) \
                    SELECT *, "cA" AS "grdb_cA", "cB" AS "grdb_cB" \
                    FROM "grandChild" WHERE ("cA", "cB") IN "grdb_base"
                    """])
            }
            
            // Request with avoided prefetch
            do {
                let request = Parent
                    .none()
                    .including(all: Parent.hasMany(Child.self)
                                .including(all: Child.hasMany(GrandChild.self)))
                    .orderByPrimaryKey()

                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "parent" WHERE 0 ORDER BY "parentA", "parentB"
                    """])
            }
            do {
                let request = Parent
                    .including(all: Parent.hasMany(Child.self)
                                .none()
                                .including(all: Child.hasMany(GrandChild.self)))
                    .orderByPrimaryKey()

                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "parent" ORDER BY "parentA", "parentB"
                    """,
                    """
                    WITH "grdb_base" AS (SELECT "parentA", "parentB" FROM "parent") \
                    SELECT *, "pA" AS "grdb_pA", "pB" AS "grdb_pB" \
                    FROM "child" \
                    WHERE 0 AND (("pA", "pB") IN "grdb_base")
                    """])
            }

            // Request with filters
            do {
                let request = Parent
                    .including(all: Parent.hasMany(Child.self)
                                .including(all: Child.hasMany(GrandChild.self)
                                            .filter(Column("name") == "dog"))
                                .filter(Column("name") == "blue"))
                    .filter(Column("name") == "foo")
                    .orderByPrimaryKey()

                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "parent" WHERE "name" = 'foo' ORDER BY "parentA", "parentB"
                    """,
                    """
                    WITH "grdb_base" AS (SELECT "parentA", "parentB" FROM "parent" WHERE "name" = 'foo') \
                    SELECT *, "pA" AS "grdb_pA", "pB" AS "grdb_pB" \
                    FROM "child" WHERE ("name" = 'blue') AND (("pA", "pB") IN "grdb_base")
                    """,
                    """
                    WITH "grdb_base" AS (\
                    WITH "grdb_base" AS (SELECT "parentA", "parentB" FROM "parent" WHERE "name" = 'foo') \
                    SELECT "childA", "childB" FROM "child" \
                    WHERE ("name" = 'blue') AND (("pA", "pB") IN "grdb_base")\
                    ) \
                    SELECT *, "cA" AS "grdb_cA", "cB" AS "grdb_cB" \
                    FROM "grandChild" \
                    WHERE ("name" = 'dog') AND (("cA", "cB") IN "grdb_base")
                    """])
            }
        }
    }
    
    func testIncludingAllHasManyIncludingRequiredOrOptionalHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .including(required: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT "c".*, "c"."colc2" AS "grdb_colc2", "d".* \
                    FROM "c" \
                    JOIN "d" ON "d"."cold2" = "c"."colc1" \
                    WHERE "c"."colc2" IN (1, 2, 3) \
                    ORDER BY "c"."colc1", "d"."cold1"
                    """])
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .none()
                        .including(required: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT "c".*, "c"."colc2" AS "grdb_colc2", "d".* \
                    FROM "c" \
                    JOIN "d" ON "d"."cold2" = "c"."colc1" \
                    WHERE 0 AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "c"."colc1", "d"."cold1"
                    """])
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") > 7)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("d1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("d2"))
                        .orderByPrimaryKey()
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("d1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("d2"))
                        .orderByPrimaryKey()
                        .forKey("cs2"))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * \
                    FROM "a" \
                    WHERE "cola1" <> 3 \
                    ORDER BY "cola1"
                    """,
                    """
                    SELECT "c".*, "c"."colc2" AS "grdb_colc2", "d1".*, "d2".* \
                    FROM "c" \
                    LEFT JOIN "d" "d1" ON ("d1"."cold2" = "c"."colc1") AND ("d1"."cold1" = 11) \
                    JOIN "d" "d2" ON ("d2"."cold2" = "c"."colc1") AND ("d2"."cold1" <> 11) \
                    WHERE ("c"."colc1" > 7) AND ("c"."colc2" IN (1, 2)) \
                    ORDER BY "c"."colc1", "d1"."cold1", "d2"."cold1"
                    """,
                    """
                    SELECT "c".*, "c"."colc2" AS "grdb_colc2", "d1".*, "d2".* \
                    FROM "c" \
                    LEFT JOIN "d" "d1" ON ("d1"."cold2" = "c"."colc1") AND ("d1"."cold1" = 11) \
                    JOIN "d" "d2" ON ("d2"."cold2" = "c"."colc1") AND ("d2"."cold1" <> 11) \
                    WHERE ("c"."colc1" < 9) AND ("c"."colc2" IN (1, 2)) \
                    ORDER BY "c"."colc1", "d1"."cold1", "d2"."cold1"
                    """])
            }
        }
    }
    
    func testIncludingAllHasManyThroughHasManyUsingHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """])
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).filter(Column("colc1") == 8).forKey("cs1"), using: C.hasMany(D.self))
                        .orderByPrimaryKey()
                        .forKey("ds1"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).forKey("cs2"), using: C.hasMany(D.self))
                        .filter(Column("cold1") != 11)
                        .orderByPrimaryKey()
                        .forKey("ds2"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).forKey("cs2"), using: C.hasMany(D.self))
                        .filter(Column("cold1") == 11)
                        .orderByPrimaryKey()
                        .forKey("ds3"))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" \
                    WHERE "cola1" <> 3 \
                    ORDER BY "cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 8) AND ("c"."colc2" IN (1, 2)) \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2)) \
                    WHERE "d"."cold1" <> 11 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2)) \
                    WHERE "d"."cold1" = 11 \
                    ORDER BY "d"."cold1"
                    """])
            }
        }
    }
    
    func testIncludingAllHasManyThroughBelongsToUsingHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = B
                    .including(all: B.hasMany(C.self, through: B.belongsTo(A.self), using: A.hasMany(C.self))
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "b" ORDER BY "colb1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola1" IN (1, 2)) \
                    ORDER BY "c"."colc1"
                    """])
            }
            
            // Request with filters
            do {
                // This request is an example of what users are unlikely to
                // want, because of the shared key between the two different
                // pivot associations.
                let request = B
                    .including(all: B
                        .hasMany(
                            C.self,
                            through: B.belongsTo(A.self).filter(Column("cola2") == "a1"),
                            using: A.hasMany(C.self))
                        .orderByPrimaryKey())
                    .including(all: B
                        .hasMany(
                            C.self,
                            through: B.belongsTo(A.self).filter(Column("cola2") != "a1"),
                            using: A.hasMany(C.self))
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "b" ORDER BY "colb1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a1') AND ("a"."cola2" <> 'a1') AND ("a"."cola1" IN (1, 2)) \
                    ORDER BY "c"."colc1"
                    """])
            }
            
            // Request with filters
            do {
                // Another example of what users are unlikely to want, still
                // because of the shared key between the two different pivot
                // associations, and despite the distinct hasMany keys.
                let request = B
                    .including(all: B
                        .hasMany(
                            C.self,
                            through: B.belongsTo(A.self).filter(Column("cola2") == "a1"),
                            using: A.hasMany(C.self))
                        .forKey("a1")
                        .orderByPrimaryKey())
                    .including(all: B
                        .hasMany(
                            C.self,
                            through: B.belongsTo(A.self).filter(Column("cola2") != "a1"),
                            using: A.hasMany(C.self))
                        .forKey("nota1")
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "b" ORDER BY "colb1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a1') AND ("a"."cola2" <> 'a1') AND ("a"."cola1" IN (1, 2)) \
                    ORDER BY "c"."colc1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a1') AND ("a"."cola2" <> 'a1') AND ("a"."cola1" IN (1, 2)) \
                    ORDER BY "c"."colc1"
                    """])
            }

            // Request with filters
            do {
                // This request is a "fixed" version of the previous request,
                // where the two different pivot associations do not share the
                // same key.
                let request = B
                    .including(all: B
                        .hasMany(
                            C.self,
                            through: B.belongsTo(A.self).filter(Column("cola2") == "a1").forKey("a1"),
                            using: A.hasMany(C.self))
                        .orderByPrimaryKey())
                    .including(all: B
                        .hasMany(
                            C.self,
                            through: B.belongsTo(A.self).filter(Column("cola2") != "a1").forKey("nota1"),
                            using: A.hasMany(C.self))
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "b" ORDER BY "colb1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a1') AND ("a"."cola1" IN (1, 2)) \
                    ORDER BY "c"."colc1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" <> 'a1') AND ("a"."cola1" IN (1, 2)) \
                    ORDER BY "c"."colc1"
                    """])
            }
        }
    }
    
    func testIncludingAllHasManyThroughHasOneUsingHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = A
                    .including(all: A.hasMany(D.self, through: A.hasOne(C.self), using: C.hasMany(D.self))
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """])
            }
            
            // Request with filters
            do {
                // This request is an example of what users are unlikely to
                // want, because of the shared key between the two different
                // pivot associations.
                // However, A.hasMany(C.self) does not conflict. Thos is an
                // indirect proof that it feeds an association kt, "as", which
                // is distinc from "a" (A.hasOne(C.self)).
                let request = A
                    .including(all: A
                        .hasMany(
                            D.self,
                            through: A.hasOne(C.self).filter(Column("colc1") == 7),
                            using: C.hasMany(D.self))
                        .orderByPrimaryKey())
                    .including(all: A
                        .hasMany(
                            D.self,
                            through: A.hasOne(C.self).filter(Column("colc1") != 7),
                            using: C.hasMany(D.self))
                        .orderByPrimaryKey())
                    .including(all: A.hasMany(C.self))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 7) AND ("c"."colc1" <> 7) AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT *, "colc2" AS "grdb_colc2" FROM "c" WHERE "colc2" IN (1, 2, 3)
                    """])
            }
            
            // Request with filters
            do {
                // Another example of what users are unlikely to want, still
                // because of the shared key between the two different pivot
                // associations, and despite the distinct hasMany keys.
                let request = A
                    .including(all: A
                        .hasMany(
                            D.self,
                            through: A.hasOne(C.self).filter(Column("colc1") == 7),
                            using: C.hasMany(D.self))
                        .forKey("c7")
                        .orderByPrimaryKey())
                    .including(all: A
                        .hasMany(
                            D.self,
                            through: A.hasOne(C.self).filter(Column("colc1") != 7),
                            using: C.hasMany(D.self))
                        .forKey("notc7")
                        .orderByPrimaryKey())
                    .including(all: A.hasMany(C.self))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 7) AND ("c"."colc1" <> 7) AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 7) AND ("c"."colc1" <> 7) AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT *, "colc2" AS "grdb_colc2" FROM "c" WHERE "colc2" IN (1, 2, 3)
                    """])
            }

            // Request with filters
            do {
                // This request is a "fixed" version of the previous request,
                // where the two different pivot associations do not share the
                // same key.
                let request = A
                    .including(all: A
                        .hasMany(
                            D.self,
                            through: A.hasOne(C.self).filter(Column("colc1") == 7).forKey("c7"),
                            using: C.hasMany(D.self))
                        .orderByPrimaryKey())
                    .including(all: A
                        .hasMany(
                            D.self,
                            through: A.hasOne(C.self).filter(Column("colc1") != 7).forKey("notc7"),
                            using: C.hasMany(D.self))
                        .orderByPrimaryKey())
                    .including(all: A.hasMany(C.self))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" ORDER BY "cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 7) AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" <> 7) AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT *, "colc2" AS "grdb_colc2" FROM "c" WHERE "colc2" IN (1, 2, 3)
                    """])
            }
        }
    }

    func testIncludingOptionalBelongsToIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = B
                    .including(optional: B
                        .belongsTo(A.self)
                        .including(all: A
                            .hasMany(C.self)
                            .orderByPrimaryKey())
                    )
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "b".*, "a".* \
                    FROM "b" \
                    LEFT JOIN "a" ON "a"."cola1" = "b"."colb2" \
                    ORDER BY "b"."colb1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola1" IN (1, 2)) \
                    ORDER BY "c"."colc1"
                    """])
            }
            
            // Request with filters
            do {
                let request = B
                    .including(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a1")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .orderByPrimaryKey()
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .orderByPrimaryKey()
                            .forKey("cs2"))
                        .forKey("a1"))
                    .including(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a2")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .orderByPrimaryKey()
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .orderByPrimaryKey()
                            .forKey("cs2"))
                        .forKey("a2"))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "b".*, "a1".*, "a2".* \
                    FROM "b" \
                    LEFT JOIN "a" "a1" ON ("a1"."cola1" = "b"."colb2") AND ("a1"."cola2" = 'a1') \
                    LEFT JOIN "a" "a2" ON ("a2"."cola1" = "b"."colb2") AND ("a2"."cola2" = 'a2') \
                    ORDER BY "b"."colb1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a1') AND ("a"."cola1" IN (1, 2)) \
                    WHERE "c"."colc1" = 9 \
                    ORDER BY "c"."colc1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a1') AND ("a"."cola1" IN (1, 2)) \
                    WHERE "c"."colc1" <> 9 \
                    ORDER BY "c"."colc1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a2') AND ("a"."cola1" IN (1, 2)) \
                    WHERE "c"."colc1" = 9 \
                    ORDER BY "c"."colc1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a2') AND ("a"."cola1" IN (1, 2)) \
                    WHERE "c"."colc1" <> 9 \
                    ORDER BY "c"."colc1"
                    """])
            }
        }
    }

    func testIncludingOptionalHasOneIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = A
                    .including(optional: A
                        .hasOne(C.self)
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                    )
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "c" ON "c"."colc2" = "a"."cola1" \
                    ORDER BY "a"."cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """])
            }

            // Request with filters
            do {
                let request = A
                    .including(optional: A
                        .hasOne(C.self)
                        .filter(Column("colc1") == 9)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .forKey("c1"))
                    .including(optional: A
                        .hasOne(C.self)
                        .filter(Column("colc1") != 9)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .forKey("c2"))
                    .orderByPrimaryKey()

                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)

                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "a".*, "c1".*, "c2".* \
                    FROM "a" \
                    LEFT JOIN "c" "c1" ON ("c1"."colc2" = "a"."cola1") AND ("c1"."colc1" = 9) \
                    LEFT JOIN "c" "c2" ON ("c2"."colc2" = "a"."cola1") AND ("c2"."colc1" <> 9) \
                    ORDER BY "a"."cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 9) AND ("c"."colc2" IN (1, 2, 3)) \
                    WHERE "d"."cold1" = 11 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 9) AND ("c"."colc2" IN (1, 2, 3)) \
                    WHERE "d"."cold1" <> 11 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" <> 9) AND ("c"."colc2" IN (1, 2, 3)) \
                    WHERE "d"."cold1" = 11 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" <> 9) AND ("c"."colc2" IN (1, 2, 3)) \
                    WHERE "d"."cold1" <> 11 \
                    ORDER BY "d"."cold1"
                    """])
            }
        }
    }
    
    func testIncludingOptionalBelongsToIncludingOptionalBelongsToIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = D
                    .including(optional: D
                        .belongsTo(C.self)
                        .including(optional: C
                            .belongsTo(A.self)
                            .including(all: A
                                .hasMany(B.self)
                                .orderByPrimaryKey())))
                    .orderByPrimaryKey()
                    .filter(Column("cold2") != 8)
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "d".*, "c".*, "a".* \
                    FROM "d" \
                    LEFT JOIN "c" ON "c"."colc1" = "d"."cold2" \
                    LEFT JOIN "a" ON "a"."cola1" = "c"."colc2" \
                    WHERE "d"."cold2" <> 8 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "b".*, "c"."colc1" AS "grdb_colc1" \
                    FROM "b" \
                    JOIN "a" ON "a"."cola1" = "b"."colb2" \
                    JOIN "c" ON ("c"."colc2" = "a"."cola1") AND ("c"."colc1" IN (7, 9)) \
                    ORDER BY "b"."colb1"
                    """])
            }
        }
    }
    
    func testIncludingOptionalHasOneThroughIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = D
                    .including(optional: D
                        .hasOne(A.self, through: D.belongsTo(C.self), using: C.belongsTo(A.self))
                        .including(all: A
                            .hasMany(B.self)
                            .orderByPrimaryKey()))
                    .orderByPrimaryKey()
                    .filter(Column("cold2") != 8)
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "d".*, "a".* \
                    FROM "d" \
                    LEFT JOIN "c" ON "c"."colc1" = "d"."cold2" \
                    LEFT JOIN "a" ON "a"."cola1" = "c"."colc2" \
                    WHERE "d"."cold2" <> 8 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "b".*, "c"."colc1" AS "grdb_colc1" \
                    FROM "b" \
                    JOIN "a" ON "a"."cola1" = "b"."colb2" \
                    JOIN "c" ON ("c"."colc2" = "a"."cola1") AND ("c"."colc1" IN (7, 9)) \
                    ORDER BY "b"."colb1"
                    """])
            }
        }
    }

    func testJoiningOptionalBelongsToIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = B
                    .joining(optional: B
                        .belongsTo(A.self)
                        .including(all: A
                            .hasMany(C.self)
                            .orderByPrimaryKey())
                    )
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                // LEFT JOIN in the first query are useless but harmless.
                // And SQLite may well optimize them out.
                // So don't bother removing them.
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "b".* \
                    FROM "b" \
                    LEFT JOIN "a" ON "a"."cola1" = "b"."colb2" \
                    ORDER BY "b"."colb1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola1" IN (1, 2)) \
                    ORDER BY "c"."colc1"
                    """])
            }
            
            // Request with filters
            do {
                let request = B
                    .joining(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a1")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .orderByPrimaryKey()
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .orderByPrimaryKey()
                            .forKey("cs2"))
                        .forKey("a1"))
                    .joining(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a2")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .orderByPrimaryKey()
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .orderByPrimaryKey()
                            .forKey("cs2"))
                        .forKey("a2"))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                // LEFT JOIN in the first query are useless but harmless.
                // And SQLite may well optimize them out.
                // So don't bother removing them.
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "b".* \
                    FROM "b" \
                    LEFT JOIN "a" "a1" ON ("a1"."cola1" = "b"."colb2") AND ("a1"."cola2" = 'a1') \
                    LEFT JOIN "a" "a2" ON ("a2"."cola1" = "b"."colb2") AND ("a2"."cola2" = 'a2') \
                    ORDER BY "b"."colb1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a1') AND ("a"."cola1" IN (1, 2)) \
                    WHERE "c"."colc1" = 9 \
                    ORDER BY "c"."colc1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a1') AND ("a"."cola1" IN (1, 2)) \
                    WHERE "c"."colc1" <> 9 \
                    ORDER BY "c"."colc1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a2') AND ("a"."cola1" IN (1, 2)) \
                    WHERE "c"."colc1" = 9 \
                    ORDER BY "c"."colc1"
                    """,
                    """
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND ("a"."cola2" = 'a2') AND ("a"."cola1" IN (1, 2)) \
                    WHERE "c"."colc1" <> 9 \
                    ORDER BY "c"."colc1"
                    """])
            }
        }
    }
    
    func testJoiningOptionalHasOneIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = A
                    .joining(optional: A
                        .hasOne(C.self)
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                    )
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                // LEFT JOIN in the first query are useless but harmless.
                // And SQLite may well optimize them out.
                // So don't bother removing them.
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "c" ON "c"."colc2" = "a"."cola1" \
                    ORDER BY "a"."cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3)) \
                    ORDER BY "d"."cold1"
                    """])
            }
            
            // Request with filters
            do {
                let request = A
                    .joining(optional: A
                        .hasOne(C.self)
                        .filter(Column("colc1") == 9)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .forKey("c1"))
                    .joining(optional: A
                        .hasOne(C.self)
                        .filter(Column("colc1") != 9)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .forKey("c2"))
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                // LEFT JOIN in the first query are useless but harmless.
                // And SQLite may well optimize them out.
                // So don't bother removing them.
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "c" "c1" ON ("c1"."colc2" = "a"."cola1") AND ("c1"."colc1" = 9) \
                    LEFT JOIN "c" "c2" ON ("c2"."colc2" = "a"."cola1") AND ("c2"."colc1" <> 9) \
                    ORDER BY "a"."cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 9) AND ("c"."colc2" IN (1, 2, 3)) \
                    WHERE "d"."cold1" = 11 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" = 9) AND ("c"."colc2" IN (1, 2, 3)) \
                    WHERE "d"."cold1" <> 11 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" <> 9) AND ("c"."colc2" IN (1, 2, 3)) \
                    WHERE "d"."cold1" = 11 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc1" <> 9) AND ("c"."colc2" IN (1, 2, 3)) \
                    WHERE "d"."cold1" <> 11 \
                    ORDER BY "d"."cold1"
                    """])
            }
        }
    }
    
    func testJoiningOptionalBelongsToJoiningOptionalBelongsToIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = D
                    .joining(optional: D
                        .belongsTo(C.self)
                        .joining(optional: C
                            .belongsTo(A.self)
                            .including(all: A
                                .hasMany(B.self)
                                .orderByPrimaryKey())))
                    .orderByPrimaryKey()
                    .filter(Column("cold2") != 8)
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                // LEFT JOIN in the first query are useless but harmless.
                // And SQLite may well optimize them out.
                // So don't bother removing them.
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "d".* \
                    FROM "d" \
                    LEFT JOIN "c" ON "c"."colc1" = "d"."cold2" \
                    LEFT JOIN "a" ON "a"."cola1" = "c"."colc2" \
                    WHERE "d"."cold2" <> 8 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "b".*, "c"."colc1" AS "grdb_colc1" \
                    FROM "b" \
                    JOIN "a" ON "a"."cola1" = "b"."colb2" \
                    JOIN "c" ON ("c"."colc2" = "a"."cola1") AND ("c"."colc1" IN (7, 9)) \
                    ORDER BY "b"."colb1"
                    """])
            }
        }
    }
    
    func testJoiningOptionalHasOneThroughIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = D
                    .joining(optional: D
                        .hasOne(A.self, through: D.belongsTo(C.self), using: C.belongsTo(A.self))
                        .including(all: A
                            .hasMany(B.self)
                            .orderByPrimaryKey()))
                    .orderByPrimaryKey()
                    .filter(Column("cold2") != 8)
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                // LEFT JOIN in the first query are useless but harmless.
                // And SQLite may well optimize them out.
                // So don't bother removing them.
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT "d".* \
                    FROM "d" \
                    LEFT JOIN "c" ON "c"."colc1" = "d"."cold2" \
                    LEFT JOIN "a" ON "a"."cola1" = "c"."colc2" \
                    WHERE "d"."cold2" <> 8 \
                    ORDER BY "d"."cold1"
                    """,
                    """
                    SELECT "b".*, "c"."colc1" AS "grdb_colc1" \
                    FROM "b" \
                    JOIN "a" ON "a"."cola1" = "b"."colb2" \
                    JOIN "c" ON ("c"."colc2" = "a"."cola1") AND ("c"."colc1" IN (7, 9)) \
                    ORDER BY "b"."colb1"
                    """])
            }
        }
    }
    
    func testAssociationFilteredByOtherAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(
                            D.self,
                            through: A.hasMany(C.self)
                                .joining(required: C.belongsTo(A.self).filter(sql: "1")),
                            using: C.hasMany(D.self))
                        .orderByPrimaryKey())
                    .filter(sql: "1 + 1")
                    .orderByPrimaryKey()
                
                sqlQueries.removeAll()
                _ = try Row.fetchAll(db, request)
                
                let selectQueries = sqlQueries.filter(isSelectQuery)
                XCTAssertEqual(selectQueries, [
                    """
                    SELECT * FROM "a" WHERE 1 + 1 ORDER BY "cola1"
                    """,
                    """
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON ("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3)) \
                    JOIN "a" ON ("a"."cola1" = "c"."colc2") AND (1) \
                    ORDER BY "d"."cold1"
                    """])
            }
        }
    }
    
    // Return SELECT queries, but omit schema queries.
    private func isSelectQuery(_ query: String) -> Bool {
        return query.contains("SELECT") && !query.contains("sqlite_") && !query.contains("pragma_table_xinfo")
    }
}
