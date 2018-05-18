import GRDB

//: This playground demonstrates how one can implement **customized decoding of
//: database rows**.
//:
//: Customized row decoding allows you to go beyong the built-in support for
//: requests of raw rows, values, or types that adopt the
//: FetchableRecord protocol.
//:
//: For example:
//:
//: - Your application needs polymorphic row decoding (which means decoding some
//: class or another depending on the values contained in a database row).
//:
//: - Your application needs to decode rows with a context - which means that
//: each decoded value should be initialized with some extra value that does not
//: come from the database.
//:
//: - Your application needs a record type that supports untrusted databases,
//: and may fail at decoding database rows (throw an error when a row contains
//: invalid values).
//:
//: None of those use cases can be handled by the built-in `FetchableRecord`
//: protocol and its `init(row:)` initializer. They need *customized
//: row decoding*.
//:
//: In this playground, we will provide some sample code that performs
//: polymorphic row decoding. Given a base class, `Base`, and two subclasses
//: `Foo` and `Bar`, we'd like to fetch Foo or Bar instances, depending on the
//: value found in the `type` column of the `base` database table.
//:
//: From this sample code, we hope that you will be able to derive your own
//: customized decoding.
//:
//: Everything starts from our class hierarchy:

class Base {
    var description: String { return "Base" }
    init() { }
}

class Foo: Base {
    var name: String
    override var description: String { return "Foo: \(name)" }
    init(name: String) {
        self.name = name
        super.init()
    }
}

class Bar: Base {
    var score: Int
    override var description: String { return "Bar: \(score)" }
    init(score: Int) {
        self.score = score
        super.init()
    }
}

//: We need a database, a table, and a few values so that we can do a real demo:

// An in-memory database is good enough
let dbQueue = DatabaseQueue()

try dbQueue.write { db in
    // Database table
    try db.create(table: "base") { t in
        t.column("type", .text).notNull()   // Contains "Foo" or "Bar"
        t.column("fooName", .text)          // Contains a Foo's name
        t.column("barScore", .integer)      // Contains a Bar's score
    }
    
    // Demo values: two Foo and one Bar
    try db.execute("""
        INSERT INTO base (type, fooName, barScore) VALUES (?, ?, ?);
        INSERT INTO base (type, fooName, barScore) VALUES (?, ?, ?);
        INSERT INTO base (type, fooName, barScore) VALUES (?, ?, ?);
        """, arguments: [
            "Foo", "Arthur", nil,
            "Bar", nil, 100,
            "Foo", "Barbara", nil,
            ])
}

//: We also need a method that decodes database rows into `Foo` or `Bar`
//: instances: let's call it `Base.decode(row:)`:

extension Base {
    static func decode(row: Row) -> Base {
        switch row["type"] as String {
        case "Foo":
            return Foo(name: row["fooName"])
        case "Bar":
            return Bar(score: row["barScore"])
        case let type:
            fatalError("Unknown Base type: \(type)")
        }
    }
}

//: Now we are able to express the kind of request we'd like to write. For
//: example, we could fetch all Base values from the database:
//:
//:     try dbQueue.read { db in
//:         // An array [Base] that constains Foo and Bar instances
//:         let bases = try Base.fetchAll(db)
//:     }
//:
//: But so far, we have a compiler error:

// Compiler error: Type 'Base' has no member 'fetchAll'
//try dbQueue.read { db in
//    let bases = try Base.fetchAll(db)
//}

//: We'll see that this goal can be achieved by declaring a protocol, writing a
//: few extensions that guarantee the most efficient use of GRDB, and have the
//: Base class adopt this protocol.
//:
//: But first, let's see how polymorphic decoding can be done as simply as
//: possible. After all, it is useless to design a full-fledged protocol unless
//: we need to use this protocol several times, or write code that is as
//: streamlined as possible. Keep it simple, stupid!
//:
//: Can we fetch Foo and Bar values from an SQL request? Sure:

try dbQueue.read { db in
    print("> KISS: Fetch from SQL")
    let rows = try Row.fetchAll(db, "SELECT * FROM base")   // Fetch database rows
    let bases = rows.map { row in                           // Decode database rows
        Base.decode(row: row)
    }
    for base in bases {                                     // Use fetched values
        print(base.description)
    }
}

//: Can we have GRDB generate SQL for us? Sure, we just need to adopt the
//: `TableRecord` protocol:

extension Base: TableRecord {
    static let databaseTableName = "base"
}

try dbQueue.read { db in
    print("> KISS: Fetch from query interface request")
    let request = Base.filter(Column("type") == "Foo")  // Define a request
    let rows = try Row.fetchAll(db, request)            // Fetch database rows
    let bases = rows.map { row in                       // Decode database rows
        Base.decode(row: row)
    }
    for base in bases {                                 // Use fetched values
        print(base.description)
    }
}

//: As seen above, we can perform polymorphic requests with the standard GRDB,
//: by fetching raw rows and mapping them through a decoding method.
//:
//: The resulting code is not as streamlined as usual GRDB code, but we could
//: already do what we needed without much effort.
//:
//: In the rest of this playground, we will define a **new realm of requests**.
//:
//: GRDB ships with three build-in realms of requests: requests of raw rows,
//: requests of values, and requests of record types that adopt the
//: `FetchableRecord` protocol.
//:
//: We'll define requests of record types that adopt the custom
//: `DatabaseDecoder` protocol:

protocol DatabaseDecoder {
    associatedtype DecodedType
    static func decode(row: Row) -> DecodedType
}

//: Types that adopt the DatabaseDecoder protocol are able to perform the
//: polymorphic decoding of our Base type:

extension Base: DatabaseDecoder {
    // Uses the decode(row: Row) already declared above
}

//: 

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

// MARK: Fetching From Base Tye

/// Fetch from SQL:
///
///     struct Decoder: DatabaseDecoder { ... }
///     try dbQueue.read { db in
///         let values = try Decoder.fetchAll(db)
///     }
extension DatabaseDecoder where Self: TableRecord {
    static func fetchCursor(_ db: Database) throws -> MapCursor<RowCursor, DecodedType> {
        return try all().fetchCursor(db)
    }
    
    static func fetchAll(_ db: Database) throws -> [DecodedType] {
        return try all().fetchAll(db)
    }
    
    static func fetchOne(_ db: Database) throws -> DecodedType? {
        return try all().fetchOne(db)
    }
}

// =============================================================================

try dbQueue.read { db in
    do {
        print("> Fetch from SQL")
        let bases = try Base.fetchAll(db, "SELECT * FROM base")
        for base in bases {
            print(base.description)
        }
    }
    
    do {
        print("> Fetch from query interface request")
        let bases = try Base.filter(Column("type") == "Foo").fetchAll(db)
        for base in bases {
            print(base.description)
        }
    }
    
    do {
        print("> Fetch right from the Base type")
        let bases = try Base.fetchAll(db)
        for base in bases {
            print(base.description)
        }
    }
}
