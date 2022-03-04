import XCTest
import GRDB

let expectedSQL = """
    SELECT
        "t1".*,
        "t2Left".*,
        "t2Right".*,
        "t3"."t1id", "t3"."name",
        COUNT(DISTINCT t5.id) AS t5count
    FROM t1
    LEFT JOIN t2 t2Left ON t2Left.t1id = t1.id AND t2Left.name = 'left'
    LEFT JOIN t2 t2Right ON t2Right.t1id = t1.id AND t2Right.name = 'right'
    LEFT JOIN t3 ON t3.t1id = t1.id
    LEFT JOIN t4 ON t4.t1id = t1.id
    LEFT JOIN t5 ON t5.t3id = t3.t1id OR t5.t4id = t4.t1id
    GROUP BY t1.id
    ORDER BY t1.id
    """

let testedLiteral: SQL = """
    SELECT
        \(columnsOf: T1.self),
        \(columnsOf: T2.self, tableAlias: "t2Left"),
        \(columnsOf: T2.self, tableAlias: "t2Right"),
        \(columnsOf: T3.self),
        COUNT(DISTINCT t5.id) AS t5count
    FROM t1
    LEFT JOIN t2 t2Left ON t2Left.t1id = t1.id AND t2Left.name = 'left'
    LEFT JOIN t2 t2Right ON t2Right.t1id = t1.id AND t2Right.name = 'right'
    LEFT JOIN t3 ON t3.t1id = t1.id
    LEFT JOIN t4 ON t4.t1id = t1.id
    LEFT JOIN t5 ON t5.t3id = t3.t1id OR t5.t4id = t4.t1id
    GROUP BY t1.id
    ORDER BY t1.id
    """

private struct T1: Codable, FetchableRecord, TableRecord {
    static let databaseTableName = "t1"
    var id: Int64
    var name: String
}

private struct T2: Codable, FetchableRecord, TableRecord {
    static let databaseTableName = "t2"
    var id: Int64
    var t1id: Int64
    var name: String
}

private struct T3: Codable, FetchableRecord, TableRecord {
    static let databaseTableName = "t3"
    static let databaseSelection: [SQLSelectable] = [Column("t1id"), Column("name")]
    var t1id: Int64
    var name: String
}

private struct T4: Codable, FetchableRecord, TableRecord {
    static let databaseTableName = "t4"
    var t1id: Int64
    var name: String
}

private struct T5: Codable, FetchableRecord, TableRecord {
    static let databaseTableName = "t5"
    var id: Int64
    var t3id: Int64?
    var t4id: Int64?
    var name: String
}

private struct FlatModel: FetchableRecord {
    private enum Scopes {
        static let t1 = "t1"
        static let t2Left = "t2Left"
        static let t2Right = "t2Right"
        static let t3 = "t3"
        static let suffix = "suffix"
    }

    var t1: T1
    var t2Left: T2?
    var t2Right: T2?
    var t3: T3?
    var t5count: Int
    
    init(row: Row) throws {
        self.t1 = try row[Scopes.t1]
        self.t2Left = try row[Scopes.t2Left]
        self.t2Right = try row[Scopes.t2Right]
        self.t3 = try row[Scopes.t3]
        self.t5count = try row.scopes[Scopes.suffix]!["t5count"]
    }
    
    static func all() -> AdaptedFetchRequest<SQLRequest<FlatModel>> {
        SQLRequest<FlatModel>(literal: testedLiteral).adapted { db in
            let adapters = try splittingRowAdapters(columnCounts: [
                T1.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T3.numberOfSelectedColumns(db)])
            return ScopeAdapter([
                Scopes.t1: adapters[0],
                Scopes.t2Left: adapters[1],
                Scopes.t2Right: adapters[2],
                Scopes.t3: adapters[3],
                Scopes.suffix: adapters[4]])
        }
    }
    
    static func hierarchicalAll() -> AdaptedFetchRequest<SQLRequest<CodableFlatModel>> {
        SQLRequest<CodableFlatModel>(literal: testedLiteral).adapted { db in
            let adapters = try splittingRowAdapters(columnCounts: [
                T1.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T3.numberOfSelectedColumns(db)])
            return ScopeAdapter([
                Scopes.t1: adapters[0],
                "t2": ScopeAdapter(base: EmptyRowAdapter(), scopes: [
                    Scopes.t2Left: adapters[1],
                    Scopes.t2Right: adapters[2]]),
                Scopes.t3: adapters[3],
                Scopes.suffix: adapters[4]])
        }
    }
}

private struct CodableFlatModel: FetchableRecord, Codable {
    var t1: T1
    var t2Left: T2?
    var t2Right: T2?
    var t3: T3?
    var t5count: Int
    
    static func all() -> AdaptedFetchRequest<SQLRequest<CodableFlatModel>> {
        SQLRequest<CodableFlatModel>(literal: testedLiteral).adapted { db in
            let adapters = try splittingRowAdapters(columnCounts: [
                T1.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T3.numberOfSelectedColumns(db)])
            return ScopeAdapter([
                CodingKeys.t1.stringValue: adapters[0],
                CodingKeys.t2Left.stringValue: adapters[1],
                CodingKeys.t2Right.stringValue: adapters[2],
                CodingKeys.t3.stringValue: adapters[3]])
        }
    }
    
    static func hierarchicalAll() -> AdaptedFetchRequest<SQLRequest<CodableFlatModel>> {
        SQLRequest<CodableFlatModel>(literal: testedLiteral).adapted { db in
            let adapters = try splittingRowAdapters(columnCounts: [
                T1.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T3.numberOfSelectedColumns(db)])
            return ScopeAdapter([
                CodingKeys.t1.stringValue: adapters[0],
                "t2": ScopeAdapter(base: EmptyRowAdapter(), scopes: [
                    CodingKeys.t2Left.stringValue: adapters[1],
                    CodingKeys.t2Right.stringValue: adapters[2]]),
                CodingKeys.t3.stringValue: adapters[3]])
        }
    }
}

private struct CodableNestedModel: FetchableRecord, Codable {
    struct T2Pair: Codable {
        var left: T2?
        var right: T2?
    }
    var t1: T1
    var optionalT2Pair: T2Pair?
    var t2Pair: T2Pair
    var t3: T3?
    var t5count: Int
    
    static func all() -> AdaptedFetchRequest<SQLRequest<CodableNestedModel>> {
        SQLRequest<CodableNestedModel>(literal: testedLiteral).adapted { db in
            let adapters = try splittingRowAdapters(columnCounts: [
                T1.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T2.numberOfSelectedColumns(db),
                T3.numberOfSelectedColumns(db)])
            return ScopeAdapter([
                CodingKeys.t1.stringValue: adapters[0],
                CodingKeys.optionalT2Pair.stringValue: ScopeAdapter(base: EmptyRowAdapter(), scopes: [ // EmptyRowAdapter base so that optionalT2Pair only instantiates when its scopes contain non-null values
                    "left": adapters[1],
                    "right": adapters[2]]),
                CodingKeys.t2Pair.stringValue: ScopeAdapter([
                    "left": adapters[1],
                    "right": adapters[2]]),
                CodingKeys.t3.stringValue: adapters[3]])
        }
    }
}

class JoinSupportTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "t1") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull()
            }
            try db.create(table: "t2") { t in
                t.column("id", .integer).primaryKey()
                t.column("t1id", .integer).notNull().references("t1", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.uniqueKey(["t1id", "name"])
            }
            try db.create(table: "t3") { t in
                t.column("t1id", .integer).primaryKey().references("t1", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("ignored", .integer)
            }
            try db.create(table: "t4") { t in
                t.column("t1id", .integer).primaryKey().references("t1", onDelete: .cascade)
                t.column("name", .text).notNull()
            }
            try db.create(table: "t5") { t in
                t.column("id", .integer).primaryKey()
                t.column("t3id", .integer).references("t3", onDelete: .cascade)
                t.column("t4id", .integer).references("t4", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.check(sql: "(t3id IS NOT NULL) + (t4id IS NOT NULL) = 1")
            }
            
            // Sample data
            
            try db.execute(sql: """
                INSERT INTO t1 (id, name) VALUES (1, 'A1');
                INSERT INTO t1 (id, name) VALUES (2, 'A2');
                INSERT INTO t1 (id, name) VALUES (3, 'A3');
                INSERT INTO t2 (id, t1id, name) VALUES (1, 1, 'left');
                INSERT INTO t2 (id, t1id, name) VALUES (2, 1, 'right');
                INSERT INTO t2 (id, t1id, name) VALUES (3, 2, 'left');
                INSERT INTO t3 (t1id, name) VALUES (1, 'A3');
                INSERT INTO t4 (t1id, name) VALUES (1, 'A4');
                INSERT INTO t4 (t1id, name) VALUES (2, 'B4');
                INSERT INTO t5 (id, t3id, t4id, name) VALUES (1, 1, NULL, 'A5');
                INSERT INTO t5 (id, t3id, t4id, name) VALUES (2, 1, NULL, 'B5');
                INSERT INTO t5 (id, t3id, t4id, name) VALUES (3, NULL, 1, 'C5');
                INSERT INTO t5 (id, t3id, t4id, name) VALUES (4, NULL, 1, 'D5');
                INSERT INTO t5 (id, t3id, t4id, name) VALUES (5, NULL, 1, 'E5');
                INSERT INTO t5 (id, t3id, t4id, name) VALUES (6, NULL, 2, 'F5');
                INSERT INTO t5 (id, t3id, t4id, name) VALUES (7, NULL, 2, 'G5');
                """)
        }
    }
    
    func testNumberOfSelectedColumns() throws {
        struct T: TableRecord { }
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "CREATE TABLE t (a)")
            try XCTAssertEqual(T.numberOfSelectedColumns(db), 1)
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "CREATE TABLE t (a, b)")
            try XCTAssertEqual(T.numberOfSelectedColumns(db), 2)
            return .rollback
        }
    }
    
    func testNumberOfSelectedColumnsIncludeGeneratedColumns() throws {
        #if !GRDBCUSTOMSQLITE
        throw XCTSkip("Generated columns are not available")
        #else
        struct T: TableRecord { }
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "CREATE TABLE t (a, b ALWAYS GENERATED AS (a) VIRTUAL)")
            try XCTAssertEqual(T.numberOfSelectedColumns(db), 2)
            return .rollback
        }
        
        try dbQueue.inTransaction { db in
            try db.execute(sql: "CREATE TABLE t (a, b ALWAYS GENERATED AS (a) STORED)")
            try XCTAssertEqual(T.numberOfSelectedColumns(db), 2)
            return .rollback
        }
        #endif
    }
    
    func testSampleData() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let rows = try SQLRequest<Row>(literal: testedLiteral).fetchAll(db)
            XCTAssertEqual(rows.count, 3)
            XCTAssertEqual(rows[0], [
                // t1.*
                "id": 1, "name": "A1",
                // t2Left.*
                "id": 1, "t1id": 1, "name": "left",
                // t2Right.*
                "id": 2, "t1id": 1, "name": "right",
                // t3.*
                "t1id": 1, "name": "A3",
                // t5count
                "t5count": 5])
            XCTAssertEqual(rows[1], [
                // t1.*
                "id": 2, "name": "A2",
                // t2Left.*
                "id": 3, "t1id": 2, "name": "left",
                // t2Right.*
                "id": nil, "t1id": nil, "name": nil,
                // t3.*
                "t1id": nil, "name": nil,
                // t5count
                "t5count": 2])
            XCTAssertEqual(rows[2], [
                // t1.*
                "id": 3, "name": "A3",
                // t2Left.*
                "id": nil, "t1id": nil, "name": nil,
                // t2Right.*
                "id": nil, "t1id": nil, "name": nil,
                // t3.*
                "t1id": nil, "name": nil,
                // t5count
                "t5count": 0])
        }
    }
    
    func testTestedSQL() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let (testedSQL, _) = try testedLiteral.build(db)
            XCTAssertEqual(testedSQL, expectedSQL)
        }
    }
    
    func testSplittingRowAdapters() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = SQLRequest<Row>(literal: testedLiteral).adapted { db in
                let adapters = try splittingRowAdapters(columnCounts: [
                    T1.numberOfSelectedColumns(db),
                    T2.numberOfSelectedColumns(db),
                    T2.numberOfSelectedColumns(db),
                    T3.numberOfSelectedColumns(db)])
                XCTAssertEqual(adapters.count, 5)
                return ScopeAdapter([
                    "t1": adapters[0],
                    "t2Left": adapters[1],
                    "t2Right": adapters[2],
                    "t3": adapters[3],
                    "suffix": adapters[4]])
            }
            let rows = try request.fetchAll(db)
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, [
                // t1.*
                "id": 1, "name": "A1",
                // t2Left.*
                "id": 1, "t1id": 1, "name": "left",
                // t2Right.*
                "id": 2, "t1id": 1, "name": "right",
                // t3.*
                "t1id": 1, "name": "A3",
                // t5count
                "t5count": 5])
            XCTAssertEqual(rows[0].scopes["t1"]!, ["id": 1, "name": "A1"])
            XCTAssertEqual(rows[0].scopes["t2Left"]!, ["id": 1, "t1id": 1, "name": "left"])
            XCTAssertEqual(rows[0].scopes["t2Right"]!, ["id": 2, "t1id": 1, "name": "right"])
            XCTAssertEqual(rows[0].scopes["t3"]!, ["t1id": 1, "name": "A3"])
            XCTAssertEqual(rows[0].scopes["suffix"]!, ["t5count": 5])
            
            XCTAssertEqual(rows[1].unscoped, [
                // t1.*
                "id": 2, "name": "A2",
                // t2Left.*
                "id": 3, "t1id": 2, "name": "left",
                // t2Right.*
                "id": nil, "t1id": nil, "name": nil,
                // t3.*
                "t1id": nil, "name": nil,
                // t5count
                "t5count": 2])
            XCTAssertEqual(rows[1].scopes["t1"]!, ["id": 2, "name": "A2"])
            XCTAssertEqual(rows[1].scopes["t2Left"]!, ["id": 3, "t1id": 2, "name": "left"])
            XCTAssertEqual(rows[1].scopes["t2Right"]!, ["id": nil, "t1id": nil, "name": nil])
            XCTAssertEqual(rows[1].scopes["t3"]!, ["t1id": nil, "name": nil])
            XCTAssertEqual(rows[1].scopes["suffix"]!, ["t5count": 2])
            
            XCTAssertEqual(rows[2].unscoped, [
                // t1.*
                "id": 3, "name": "A3",
                // t2Left.*
                "id": nil, "t1id": nil, "name": nil,
                // t2Right.*
                "id": nil, "t1id": nil, "name": nil,
                // t3.*
                "t1id": nil, "name": nil,
                // t5count
                "t5count": 0])
            XCTAssertEqual(rows[2].scopes["t1"]!, ["id": 3, "name": "A3"])
            XCTAssertEqual(rows[2].scopes["t2Left"]!, ["id": nil, "t1id": nil, "name": nil])
            XCTAssertEqual(rows[2].scopes["t2Right"]!, ["id": nil, "t1id": nil, "name": nil])
            XCTAssertEqual(rows[2].scopes["t3"]!, ["t1id": nil, "name": nil])
            XCTAssertEqual(rows[2].scopes["suffix"]!, ["t5count": 0])
        }
    }
    
    func testFlatModel() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let models = try FlatModel.all().fetchAll(db)
            XCTAssertEqual(models.count, 3)

            XCTAssertEqual(models[0].t1.id, 1)
            XCTAssertEqual(models[0].t1.name, "A1")
            XCTAssertEqual(models[0].t2Left!.id, 1)
            XCTAssertEqual(models[0].t2Left!.t1id, 1)
            XCTAssertEqual(models[0].t2Left!.name, "left")
            XCTAssertEqual(models[0].t2Right!.id, 2)
            XCTAssertEqual(models[0].t2Right!.t1id, 1)
            XCTAssertEqual(models[0].t2Right!.name, "right")
            XCTAssertEqual(models[0].t3!.t1id, 1)
            XCTAssertEqual(models[0].t3!.name, "A3")
            XCTAssertEqual(models[0].t5count, 5)
            
            XCTAssertEqual(models[1].t1.id, 2)
            XCTAssertEqual(models[1].t1.name, "A2")
            XCTAssertEqual(models[1].t2Left!.id, 3)
            XCTAssertEqual(models[1].t2Left!.t1id, 2)
            XCTAssertEqual(models[1].t2Left!.name, "left")
            XCTAssertNil(models[1].t2Right)
            XCTAssertNil(models[1].t3)
            XCTAssertEqual(models[1].t5count, 2)
            
            XCTAssertEqual(models[2].t1.id, 3)
            XCTAssertEqual(models[2].t1.name, "A3")
            XCTAssertNil(models[2].t2Left)
            XCTAssertNil(models[2].t2Right)
            XCTAssertNil(models[2].t3)
            XCTAssertEqual(models[2].t5count, 0)
        }
    }
    
    func testFlatModelFromHierarchicalRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let models = try FlatModel.hierarchicalAll().fetchAll(db)
            XCTAssertEqual(models.count, 3)
            
            XCTAssertEqual(models[0].t1.id, 1)
            XCTAssertEqual(models[0].t1.name, "A1")
            XCTAssertEqual(models[0].t2Left!.id, 1)
            XCTAssertEqual(models[0].t2Left!.t1id, 1)
            XCTAssertEqual(models[0].t2Left!.name, "left")
            XCTAssertEqual(models[0].t2Right!.id, 2)
            XCTAssertEqual(models[0].t2Right!.t1id, 1)
            XCTAssertEqual(models[0].t2Right!.name, "right")
            XCTAssertEqual(models[0].t3!.t1id, 1)
            XCTAssertEqual(models[0].t3!.name, "A3")
            XCTAssertEqual(models[0].t5count, 5)
            
            XCTAssertEqual(models[1].t1.id, 2)
            XCTAssertEqual(models[1].t1.name, "A2")
            XCTAssertEqual(models[1].t2Left!.id, 3)
            XCTAssertEqual(models[1].t2Left!.t1id, 2)
            XCTAssertEqual(models[1].t2Left!.name, "left")
            XCTAssertNil(models[1].t2Right)
            XCTAssertNil(models[1].t3)
            XCTAssertEqual(models[1].t5count, 2)
            
            XCTAssertEqual(models[2].t1.id, 3)
            XCTAssertEqual(models[2].t1.name, "A3")
            XCTAssertNil(models[2].t2Left)
            XCTAssertNil(models[2].t2Right)
            XCTAssertNil(models[2].t3)
            XCTAssertEqual(models[2].t5count, 0)
        }
    }
    
    func testCodableFlatModel() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let models = try CodableFlatModel.all().fetchAll(db)
            XCTAssertEqual(models.count, 3)
            
            XCTAssertEqual(models[0].t1.id, 1)
            XCTAssertEqual(models[0].t1.name, "A1")
            XCTAssertEqual(models[0].t2Left!.id, 1)
            XCTAssertEqual(models[0].t2Left!.t1id, 1)
            XCTAssertEqual(models[0].t2Left!.name, "left")
            XCTAssertEqual(models[0].t2Right!.id, 2)
            XCTAssertEqual(models[0].t2Right!.t1id, 1)
            XCTAssertEqual(models[0].t2Right!.name, "right")
            XCTAssertEqual(models[0].t3!.t1id, 1)
            XCTAssertEqual(models[0].t3!.name, "A3")
            XCTAssertEqual(models[0].t5count, 5)
            
            XCTAssertEqual(models[1].t1.id, 2)
            XCTAssertEqual(models[1].t1.name, "A2")
            XCTAssertEqual(models[1].t2Left!.id, 3)
            XCTAssertEqual(models[1].t2Left!.t1id, 2)
            XCTAssertEqual(models[1].t2Left!.name, "left")
            XCTAssertNil(models[1].t2Right)
            XCTAssertNil(models[1].t3)
            XCTAssertEqual(models[1].t5count, 2)
            
            XCTAssertEqual(models[2].t1.id, 3)
            XCTAssertEqual(models[2].t1.name, "A3")
            XCTAssertNil(models[2].t2Left)
            XCTAssertNil(models[2].t2Right)
            XCTAssertNil(models[2].t3)
            XCTAssertEqual(models[2].t5count, 0)
        }
    }
    
    func testCodableFlatModelFromHierarchicalRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let models = try CodableFlatModel.hierarchicalAll().fetchAll(db)
            XCTAssertEqual(models.count, 3)
            
            XCTAssertEqual(models[0].t1.id, 1)
            XCTAssertEqual(models[0].t1.name, "A1")
            XCTAssertEqual(models[0].t2Left!.id, 1)
            XCTAssertEqual(models[0].t2Left!.t1id, 1)
            XCTAssertEqual(models[0].t2Left!.name, "left")
            XCTAssertEqual(models[0].t2Right!.id, 2)
            XCTAssertEqual(models[0].t2Right!.t1id, 1)
            XCTAssertEqual(models[0].t2Right!.name, "right")
            XCTAssertEqual(models[0].t3!.t1id, 1)
            XCTAssertEqual(models[0].t3!.name, "A3")
            XCTAssertEqual(models[0].t5count, 5)
            
            XCTAssertEqual(models[1].t1.id, 2)
            XCTAssertEqual(models[1].t1.name, "A2")
            XCTAssertEqual(models[1].t2Left!.id, 3)
            XCTAssertEqual(models[1].t2Left!.t1id, 2)
            XCTAssertEqual(models[1].t2Left!.name, "left")
            XCTAssertNil(models[1].t2Right)
            XCTAssertNil(models[1].t3)
            XCTAssertEqual(models[1].t5count, 2)
            
            XCTAssertEqual(models[2].t1.id, 3)
            XCTAssertEqual(models[2].t1.name, "A3")
            XCTAssertNil(models[2].t2Left)
            XCTAssertNil(models[2].t2Right)
            XCTAssertNil(models[2].t3)
            XCTAssertEqual(models[2].t5count, 0)
        }
    }
    
    func testCodableNestedModel() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let models = try CodableNestedModel.all().fetchAll(db)
            XCTAssertEqual(models.count, 3)
            
            XCTAssertEqual(models[0].t1.id, 1)
            XCTAssertEqual(models[0].t1.name, "A1")
            XCTAssertEqual(models[0].optionalT2Pair!.left!.id, 1)
            XCTAssertEqual(models[0].optionalT2Pair!.left!.t1id, 1)
            XCTAssertEqual(models[0].optionalT2Pair!.left!.name, "left")
            XCTAssertEqual(models[0].optionalT2Pair!.right!.id, 2)
            XCTAssertEqual(models[0].optionalT2Pair!.right!.t1id, 1)
            XCTAssertEqual(models[0].optionalT2Pair!.right!.name, "right")
            XCTAssertEqual(models[0].t2Pair.left!.id, 1)
            XCTAssertEqual(models[0].t2Pair.left!.t1id, 1)
            XCTAssertEqual(models[0].t2Pair.left!.name, "left")
            XCTAssertEqual(models[0].t2Pair.right!.id, 2)
            XCTAssertEqual(models[0].t2Pair.right!.t1id, 1)
            XCTAssertEqual(models[0].t2Pair.right!.name, "right")
            XCTAssertEqual(models[0].t3!.t1id, 1)
            XCTAssertEqual(models[0].t3!.name, "A3")
            XCTAssertEqual(models[0].t5count, 5)
            
            XCTAssertEqual(models[1].t1.id, 2)
            XCTAssertEqual(models[1].t1.name, "A2")
            XCTAssertEqual(models[1].optionalT2Pair!.left!.id, 3)
            XCTAssertEqual(models[1].optionalT2Pair!.left!.t1id, 2)
            XCTAssertEqual(models[1].optionalT2Pair!.left!.name, "left")
            XCTAssertEqual(models[1].t2Pair.left!.id, 3)
            XCTAssertEqual(models[1].t2Pair.left!.t1id, 2)
            XCTAssertEqual(models[1].t2Pair.left!.name, "left")
            XCTAssertNil(models[1].optionalT2Pair!.right)
            XCTAssertNil(models[1].t2Pair.right)
            XCTAssertNil(models[1].t3)
            XCTAssertEqual(models[1].t5count, 2)
            
            XCTAssertEqual(models[2].t1.id, 3)
            XCTAssertEqual(models[2].t1.name, "A3")
            XCTAssertNil(models[2].optionalT2Pair)
            XCTAssertNil(models[2].t2Pair.left)
            XCTAssertNil(models[2].t2Pair.right)
            XCTAssertNil(models[2].t3)
            XCTAssertEqual(models[2].t5count, 0)
        }
    }
}
