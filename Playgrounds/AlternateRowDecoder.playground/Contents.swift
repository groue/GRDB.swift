import GRDB

protocol DatabaseDecoder {
    associatedtype DecodedType
    static func decode(row: Row) -> DecodedType
}

// MARK: Fetching From SelectStatement

/// Fetch from prepared statement:
///
///     struct Decoder: DatabaseDecoder { ... }
///     try dbQueue.read { db in
///         let statement = try db.makeSelectStatement("SELECT ...")
///         let values = try Decoder.fetchAll(statement)
///     }
extension DatabaseDecoder {
    static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> MapCursor<RowCursor, DecodedType> {
        return try Row.fetchCursor(statement, arguments: arguments, adapter: adapter).map {
            self.decode(row: $0)
        }
    }
    
    static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [DecodedType] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DecodedType? {
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

// MARK: Fetching From FetchRequest

/// Fetch from request:
///
///     struct Decoder: DatabaseDecoder { ... }
///     try dbQueue.read { db in
///         let request = SQLRequest<Decoder>("SELECT ...")
///         let values = try Decoder.fetchAll(db, request)
///     }
extension DatabaseDecoder {
    static func fetchCursor<R: FetchRequest>(_ db: Database, _ request: R) throws -> MapCursor<RowCursor, DecodedType> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    static func fetchAll<R: FetchRequest>(_ db: Database, _ request: R) throws -> [DecodedType] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    static func fetchOne<R: FetchRequest>(_ db: Database, _ request: R) throws -> DecodedType? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

/// Requests can fetch, too:
///
///     struct Decoder: DatabaseDecoder { ... }
///     try dbQueue.read { db in
///         let request = SQLRequest<Decoder>("SELECT ...")
///         let values = try request.fetchAll(db)
///     }
///
///     extension Decoder: TableRecord { ... }
///     try dbQueue.read { db in
///         let request = Decoder.filter(...).order(...)
///         let values = try request.fetchAll(db)
///     }
extension FetchRequest where RowDecoder: DatabaseDecoder {
    func fetchCursor(_ db: Database) throws -> MapCursor<RowCursor, RowDecoder.DecodedType> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    func fetchAll(_ db: Database) throws -> [RowDecoder.DecodedType] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    func fetchOne(_ db: Database) throws -> RowDecoder.DecodedType? {
        return try RowDecoder.fetchOne(db, self)
    }
}

// MARK: Fetching From SQL

/// Fetch from SQL:
///
///     struct Decoder: DatabaseDecoder { ... }
///     try dbQueue.read { db in
///         let values = try Decoder.fetchAll(db, "SELECT ...")
///     }
extension DatabaseDecoder {
    static func fetchCursor(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> MapCursor<RowCursor, DecodedType> {
        return try fetchCursor(db, SQLRequest<Self>(sql, arguments: arguments, adapter: adapter))
    }
    
    static func fetchAll(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [DecodedType] {
        return try fetchAll(db, SQLRequest<Self>(sql, arguments: arguments, adapter: adapter))
    }
    
    static func fetchOne(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DecodedType? {
        return try fetchOne(db, SQLRequest<Self>(sql, arguments: arguments, adapter: adapter))
    }
}

// =============================================================================

class Base {
    var id: Int64
    var description: String { return "Base(\(id))" }
    init(id: Int64) {
        self.id = id
    }
}

class Foo: Base {
    var name: String
    override var description: String { return "Foo(\(id),\(name))" }
    init(id: Int64, name: String) {
        self.name = name
        super.init(id: id)
    }
}

class Bar: Base {
    var score: Int
    override var description: String { return "Bar(\(id),\(score))" }
    init(id: Int64, score: Int) {
        self.score = score
        super.init(id: id)
    }
}

// =============================================================================

extension Base: TableRecord {
    static let databaseTableName = "base"
}

extension Base: DatabaseDecoder {
    static func decode(row: Row) -> Base {
        switch row["type"] as String {
        case "Foo":
            return Foo(id: row["id"], name: row["name"])
        case "Bar":
            return Bar(id: row["id"], score: row["score"])
        case let type:
            fatalError("Unknown type: \(type)")
        }
    }
}

// =============================================================================

let dbQueue = DatabaseQueue()
try dbQueue.write { db in
    try db.create(table: "base") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("type", .text).notNull()
        t.column("name", .text)
        t.column("score", .integer)
    }
    try db.execute("""
        INSERT INTO base (type, name, score) VALUES (?, ?, ?);
        INSERT INTO base (type, name, score) VALUES (?, ?, ?);
        """, arguments: [
            "Foo", "Arthur", nil,
            "Bar", nil, 100
    ])
    
    do {
        // Fetch from SQL
        let bases = try Base.fetchAll(db, "SELECT * FROM base")
        for base in bases {
            print(base.description)
        }
    }
        
    do {
        // Fetch from query interface request
        let bases = try Base.order(Column("id").desc).fetchAll(db)
        for base in bases {
            print(base.description)
        }
    }
}
