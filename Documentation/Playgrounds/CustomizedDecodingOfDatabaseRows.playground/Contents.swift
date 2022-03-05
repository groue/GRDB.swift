//: # Customized Decoding of Database Rows
//:
//: To run this playground:
//:
//: - Open GRDB.xcworkspace
//: - Select the GRDBOSX scheme: menu Product > Scheme > GRDBOSX
//: - Build: menu Product > Build
//: - Select the playground in the Playgrounds Group
//: - Run the playground

import GRDB

//: This playground demonstrates how one can implement **customized decoding of
//: database rows**.
//:
//: Customized row decoding allows you to go beyond the built-in support for
//: requests of raw rows, values, or types that adopt the
//: FetchableRecord protocol.
//:
//: For example:
//:
//: - Your application needs polymorphic row decoding: it decodes some class or
//: another, depending on the values contained in a database row.
//:
//: - Your application needs to decode rows with a context: each decoded value
//: should be initialized with some extra value that does not come from
//: the database.
//:
//: - Your application needs a record type that supports untrusted databases,
//: and may fail at decoding database rows (throw an error when a row contains
//: invalid values).
//:
//: None of those use cases can be handled by the built-in `FetchableRecord`
//: protocol and its `init(row:)` initializer. They need *customized
//: row decoding*.
//:
//: ## An Example: Polymorphic Decoding
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
    var description: String { "Base" }
    init() { }
}

class Foo: Base {
    var name: String
    override var description: String { "Foo: \(name)" }
    init(name: String) {
        self.name = name
        super.init()
    }
}

class Bar: Base {
    var score: Int
    override var description: String { "Bar: \(score)" }
    init(score: Int) {
        self.score = score
        super.init()
    }
}

//: We need a database, a table, and a few values so that we can do a real demo:

// An in-memory database is good enough
let dbQueue = try DatabaseQueue()

try dbQueue.write { db in
    // Database table
    try db.create(table: "base") { t in
        t.column("type", .text).notNull()   // Contains "Foo" or "Bar"
        t.column("fooName", .text)          // Contains a Foo's name
        t.column("barScore", .integer)      // Contains a Bar's score
    }
    
    // Demo values: two Foo and one Bar
    try db.execute(
        sql: """
            INSERT INTO base (type, fooName, barScore) VALUES (?, ?, ?);
            INSERT INTO base (type, fooName, barScore) VALUES (?, ?, ?);
            INSERT INTO base (type, fooName, barScore) VALUES (?, ?, ?);
            """,
        arguments: [
            "Foo", "Arthur", nil,
            "Bar", nil, 100,
            "Foo", "Barbara", nil,
        ])
}

//: We also need a method that decodes database rows into `Foo` or `Bar`
//: instances: let's call it `Base.decode(row:)`:

extension Base {
    static func decode(row: Row) throws -> Base {
        switch try row["type"] as String {
        case "Foo":
            return try Foo(name: row["fooName"])
        case "Bar":
            return try Bar(score: row["barScore"])
        case let type:
            fatalError("Unknown Base type: \(type)")
        }
    }
}

//: Now we are able to express the kind of request we'd like to write. For
//: example, we could fetch all Base values from the database:
//:
//:     try dbQueue.read { db in
//:         // An array [Base] that contains Foo and Bar instances
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
//: ### Keep It Simple, Stupid!
//:
//: But first, let's see how polymorphic decoding can be done as simply as
//: possible. After all, it is useless to design a full-fledged protocol unless
//: we need to use this protocol several times, or write code that is as
//: streamlined as possible.
//:
//: Can we fetch Foo and Bar values from an SQL request? Sure:

try dbQueue.read { db in
    print("> KISS: Fetch from SQL")
    let rows = try Row.fetchAll(db, sql: "SELECT * FROM base") // Fetch database rows
    let bases = try rows.map { row in                       // Decode database rows
        try Base.decode(row: row)
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
    let bases = try rows.map { row in                   // Decode database rows
        try Base.decode(row: row)
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
//: ### Custom Protocol: MyDatabaseDecoder
//:
//: In the rest of this playground, we will define a **new realm of requests**.
//:
//: GRDB ships with three built-in realms of requests: requests of raw rows,
//: requests of values, and requests of record types that adopt the
//: `FetchableRecord` protocol.
//:
//: We'll define requests of record types that adopt the custom
//: `MyDatabaseDecoder` protocol:

protocol MyDatabaseDecoder {
    associatedtype DecodedType
    static func decode(row: Row) throws -> DecodedType
}

//: Types that adopt the MyDatabaseDecoder protocol are able, among other
//: things, to perform polymorphic decoding. Our Base class, for example:

extension Base: MyDatabaseDecoder {
    // Already declared above:
    // static func decode(row: Row) -> Base { ... }
}

//: Now let's see how we can define a new realm of requests based on the
//: `MyDatabaseDecoder` protocol. Our goal is to make them just as powerful as
//: ready-made requests of rows, values and FetchableRecord.
//:
//: All we need is a set of *extensions* that define the classic GRDB fetching
//: methods: `fetchOne`, `fetchAll`, and `fetchCursor`. The most fundamental one
//: is `fetchCursor`, because from it we can derive the two others.
//:
//: The first extension is the most low-level one: fetching from SQLite
//: **prepared statement**:
//:
//:     try dbQueue.read { db in
//:         let statement = try db.makeStatement(sql: "SELECT ...")
//:         try Base.fetchCursor(statement) // Cursor of Base
//:         try Base.fetchAll(statement)    // [Base]
//:         try Base.fetchOne(statement)    // Base?
//:     }

extension MyDatabaseDecoder {
    // MARK: - Fetch from Prepared Statement
    
    // Statement, StatementArguments, and RowAdapter are the fundamental
    // fetching parameters of GRDB. Make sure to accept them all:
    static func fetchCursor(_ statement: Statement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> MapCursor<RowCursor, DecodedType> {
        // Turn the cursor of raw rows into a cursor of decoded rows
        return try Row.fetchCursor(statement, arguments: arguments, adapter: adapter).map {
            try self.decode(row: $0)
        }
    }
    
    static func fetchAll(_ statement: Statement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [DecodedType] {
        // Turn the cursor into an Array
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    static func fetchOne(_ statement: Statement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> DecodedType? {
        // Consume the first value of the cursor
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

try dbQueue.read { db in
    print("> Fetch from prepared statement")
    let statement = try db.makeStatement(sql: "SELECT * FROM base")
    let bases = try Base.fetchAll(statement)
    for base in bases {
        print(base.description)
    }
}

//: Now that we can fetch from prepared statements, we can fetch when given a
//: **request**, as defined by the `FetchRequest` protocol. This is the
//: protocol for query interface requests such as `Base.all()`, or
//: `SQLRequest`, etc.
//:
//:     try dbQueue.read { db in
//:         let request = Base.all()
//:         try Base.fetchCursor(db, request) // Cursor of Base
//:         try Base.fetchAll(db, request)    // [Base]
//:         try Base.fetchOne(db, request)    // Base?
//:     }
extension MyDatabaseDecoder {
    // MARK: - Fetch from FetchRequest
    
    static func fetchCursor<R: FetchRequest>(_ db: Database, _ request: R) throws -> MapCursor<RowCursor, DecodedType> {
        let preparedRequest = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchCursor(preparedRequest.statement, adapter: preparedRequest.adapter)
    }
    
    static func fetchAll<R: FetchRequest>(_ db: Database, _ request: R) throws -> [DecodedType] {
        let preparedRequest = try request.makePreparedRequest(db, forSingleResult: false)
        return try fetchAll(preparedRequest.statement, adapter: preparedRequest.adapter)
    }
    
    static func fetchOne<R: FetchRequest>(_ db: Database, _ request: R) throws -> DecodedType? {
        // The `forSingleResult: true` argument hints the request that a single
        // row will be consumed. Some requests will add a LIMIT SQL clause.
        let preparedRequest = try request.makePreparedRequest(db, forSingleResult: true)
        return try fetchOne(preparedRequest.statement, adapter: preparedRequest.adapter)
    }
}

try dbQueue.read { db in
    print("> Fetch given a request")
    let request = Base.all()
    let bases = try Base.fetchAll(db, request)
    for base in bases {
        print(base.description)
    }
}

//: When it's fine to fetch given a request, it's even better when requests can
//: fetch, too:
//:
//:     try dbQueue.read { db in
//:         let request = Base.all()
//:         try request.fetchCursor(db) // Cursor of Base
//:         try request.fetchAll(db)    // [Base]
//:         try request.fetchOne(db)    // Base?
//:     }
extension FetchRequest where RowDecoder: MyDatabaseDecoder {
    // MARK: - FetchRequest fetching methods
    
    func fetchCursor(_ db: Database) throws -> MapCursor<RowCursor, RowDecoder.DecodedType> {
        try RowDecoder.fetchCursor(db, self)
    }
    
    func fetchAll(_ db: Database) throws -> [RowDecoder.DecodedType] {
        try RowDecoder.fetchAll(db, self)
    }
    
    func fetchOne(_ db: Database) throws -> RowDecoder.DecodedType? {
        try RowDecoder.fetchOne(db, self)
    }
}

try dbQueue.read { db in
    print("> Fetch from request")
    let request = Base.all()
    let bases = try request.fetchAll(db)
    for base in bases {
        print(base.description)
    }
}

//: Types that adopt both FetchableRecord and TableRecord are able to fetch
//: right from the base type. Let's allow this as well for MyDatabaseDecoder:
//:
//:     try dbQueue.read { db in
//:         try Base.fetchCursor(db) // Cursor of Base
//:         try Base.fetchAll(db)    // [Base]
//:         try Base.fetchOne(db)    // Base?
//:     }
extension MyDatabaseDecoder where Self: TableRecord {
    // MARK: - Static fetching methods
    
    static func fetchCursor(_ db: Database) throws -> MapCursor<RowCursor, DecodedType> {
        try all().fetchCursor(db)
    }
    
    static func fetchAll(_ db: Database) throws -> [DecodedType] {
        try all().fetchAll(db)
    }
    
    static func fetchOne(_ db: Database) throws -> DecodedType? {
        try all().fetchOne(db)
    }
}

try dbQueue.read { db in
    print("> Fetch from base type")
    let bases = try Base.fetchAll(db)
    for base in bases {
        print(base.description)
    }
}

//: Finally, you can support raw SQL as well:
//:
//:     try dbQueue.read { db in
//:         try Base.fetchAll(db,
//:             sql: "SELECT ... WHERE name = ?",
//:             arguments: ["O'Brien"]) // [Base]
//:     }
extension MyDatabaseDecoder {
    // MARK: - Fetch from SQL
    
    static func fetchCursor(_ db: Database, sql: String, arguments: StatementArguments = StatementArguments(), adapter: RowAdapter? = nil) throws -> MapCursor<RowCursor, DecodedType> {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    static func fetchAll(_ db: Database, sql: String, arguments: StatementArguments = StatementArguments(), adapter: RowAdapter? = nil) throws -> [DecodedType] {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    static func fetchOne(_ db: Database, sql: String, arguments: StatementArguments = StatementArguments(), adapter: RowAdapter? = nil) throws -> DecodedType? {
        try fetchOne(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

try dbQueue.read { db in
    print("> Fetch from SQL")
    let bases = try Base.fetchAll(db, sql: "SELECT * FROM base")
    for base in bases {
        print(base.description)
    }
}

//: Voilà! Our `MyDatabaseDecoder` protocol is now as able as the built-in
//: `FetchableRecord` protocol.
//:
//: To sum up, you have learned:
//:
//: - how to keep things simple: as long as you can fetch rows, you can decode
//: them the way you want.
//: - how to define a whole new realm of requests based on a custom protocol.
//: This involves writing a few extensions that give your protocol the same
//: fluent interface that is ready-made for the built-in FetchableRecord
//: protocol. This is more work, but you are granted with the full
//: customization freedom.
//:
//: To end this tour, let's quickly look at two other possible customized
//: row decoding strategies.
//:
//: ## An Example: Contextualized Records
//:
//: Your application needs to decode rows with a context: each decoded value
//: should be initialized with some extra value that does not come from
//: the database.
//:
//: In this case, you may define a `ContextFetchableRecord` protocol, and
//: derive all other fetching methods from the most fundamental one, which
//: fetches a cursor from a prepared statement (as we did for the
//: MyDatabaseDecoder protocol, above):

protocol ContextFetchableRecord {
    associatedtype Context
    init(row: Row, context: Context)
}

extension ContextFetchableRecord {
    static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil,
        context: Context)
        throws -> MapCursor<RowCursor, Self>
    {
        // Turn the cursor of raw rows into a cursor of decoded rows
        return try Row.fetchCursor(statement, arguments: arguments, adapter: adapter).map {
            self.init(row: $0, context: context)
        }
    }
    
    // Define fetchAll, fetchOne, and other extensions...
}

//: ## An Example: Failable Records
//:
//: Your application needs a record type that supports untrusted databases,
//: and may fail at decoding database rows (throw an error when a row contains
//: invalid values).
//:
//: In this case, you may define a `FailableFetchableRecord` protocol, and
//: derive all other fetching methods from the most fundamental one, which
//: fetches a cursor from a prepared statement (as we did for the
//: MyDatabaseDecoder protocol, above):

protocol FailableFetchableRecord {
    init(row: Row) throws
}

extension FailableFetchableRecord {
    static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: RowAdapter? = nil)
        throws -> MapCursor<RowCursor, Self>
    {
        // Turn the cursor of raw rows into a cursor of decoded rows
        return try Row.fetchCursor(statement, arguments: arguments, adapter: adapter).map {
            try self.init(row: $0)
        }
    }
    
    // Define fetchAll, fetchOne, and other extensions...
}
