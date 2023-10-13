import Foundation

/// A type that can decode itself from a database row.
///
/// To conform to `FetchableRecord`, provide an implementation for the
/// ``init(row:)-9w9yp`` initializer. This implementation is ready-made for
/// `Decodable` types.
///
/// For example:
///
/// ```swift
/// struct Player: FetchableRecord, Decodable {
///     var name: String
///     var score: Int
/// }
///
/// if let row = try Row.fetchOne(db, sql: "SELECT * FROM player") {
///     let player = try Player(row: row)
/// }
/// ```
///
/// If you add conformance to ``TableRecord``, the record type can generate
/// SQL queries for you:
///
/// ```swift
/// struct Player: FetchableRecord, TableRecord, Decodable {
///     var name: String
///     var score: Int
/// }
///
/// let players = try Player.fetchAll(db)
/// let players = try Player.order(Column("score")).fetchAll(db)
/// ```
///
/// ## Topics
///
/// ### Initializers
///
/// - ``init(row:)-9w9yp``
///
/// ### Fetching Records
/// - ``fetchCursor(_:)``
/// - ``fetchAll(_:)``
/// - ``fetchSet(_:)``
/// - ``fetchOne(_:)``
///
/// ### Fetching Records from Raw SQL
///
/// - ``fetchCursor(_:sql:arguments:adapter:)``
/// - ``fetchAll(_:sql:arguments:adapter:)``
/// - ``fetchSet(_:sql:arguments:adapter:)``
/// - ``fetchOne(_:sql:arguments:adapter:)``
///
/// ### Fetching Records from a Prepared Statement
///
/// - ``fetchCursor(_:arguments:adapter:)``
/// - ``fetchAll(_:arguments:adapter:)``
/// - ``fetchSet(_:arguments:adapter:)``
/// - ``fetchOne(_:arguments:adapter:)``
///
/// ### Fetching Records from a Request
///
/// - ``fetchCursor(_:_:)``
/// - ``fetchAll(_:_:)``
/// - ``fetchSet(_:_:)``
/// - ``fetchOne(_:_:)``
///
/// ### Fetching Records by Primary Key
///
/// - ``fetchCursor(_:ids:)``
/// - ``fetchAll(_:ids:)``
/// - ``fetchSet(_:ids:)``
/// - ``fetchOne(_:id:)``
/// - ``fetchCursor(_:keys:)-2jrm1``
/// - ``fetchAll(_:keys:)-4c8no``
/// - ``fetchSet(_:keys:)-e6uy``
/// - ``fetchOne(_:key:)-3f3hc``
/// - ``find(_:id:)``
/// - ``find(_:key:)-4kry5``
/// - ``find(_:key:)-1dfbe``
///
/// ### Fetching Record by Key
///
/// - ``fetchCursor(_:keys:)-5u9hu``
/// - ``fetchAll(_:keys:)-2addp``
/// - ``fetchSet(_:keys:)-8no3x``
/// - ``fetchOne(_:key:)-92b9m``
///
/// ### Configuring Row Decoding for the Standard Decodable Protocol
///
/// - ``databaseColumnDecodingStrategy-6uefz``
/// - ``databaseDataDecodingStrategy-71bh1``
/// - ``databaseDateDecodingStrategy-78y03``
/// - ``databaseDecodingUserInfo-77jim``
/// - ``databaseJSONDecoder(for:)-7lmxd``
/// - ``DatabaseColumnDecodingStrategy``
/// - ``DatabaseDataDecodingStrategy``
/// - ``DatabaseDateDecodingStrategy``
///
/// ### Supporting Types
/// 
/// - ``RecordCursor``
/// - ``FetchableRecordDecoder``
public protocol FetchableRecord {
    
    // MARK: - Row Decoding
    
    /// Creates a record from `row`.
    ///
    /// The row argument may be reused during the iteration of database results.
    /// If you want to keep the row for later use, make sure to store a copy:
    /// `row.copy()`.
    ///
    /// - throws: An error is thrown if the record can't be decoded from the
    ///   database row.
    init(row: Row) throws
    
    // MARK: - Customizing the Format of Database Columns
    
    /// Contextual information made available to the
    /// `Decodable.init(from:)` initializer.
    ///
    /// For example:
    ///
    /// ```swift
    /// // A key that holds a decoder's name
    /// let decoderName = CodingUserInfoKey(rawValue: "decoderName")!
    ///
    /// // A FetchableRecord + Decodable record
    /// struct Player: FetchableRecord, Decodable {
    ///     // Customize the decoder name when decoding a database row
    ///     static let databaseDecodingUserInfo: [CodingUserInfoKey: Any] = [decoderName: "Database"]
    ///
    ///     init(from decoder: Decoder) throws {
    ///         // Print the decoder name
    ///         print(decoder.userInfo[decoderName])
    ///         ...
    ///     }
    /// }
    ///
    /// // prints "Database"
    /// let player = try Player.fetchOne(db, ...)
    ///
    /// // prints "JSON"
    /// let decoder = JSONDecoder()
    /// decoder.userInfo = [decoderName: "JSON"]
    /// let player = try decoder.decode(Player.self, from: ...)
    /// ```
    static var databaseDecodingUserInfo: [CodingUserInfoKey: Any] { get }
    
    /// Returns the `JSONDecoder` that decodes the value for a given column.
    ///
    /// This method is dedicated to ``FetchableRecord`` types that also conform
    /// to the standard `Decodable` protocol and use the default
    /// ``init(row:)-4ptlh`` implementation.
    static func databaseJSONDecoder(for column: String) -> JSONDecoder
    
    /// The strategy for decoding `Data` columns.
    ///
    /// This property is dedicated to ``FetchableRecord`` types that also
    /// conform to the standard `Decodable` protocol and use the default
    /// ``init(row:)-4ptlh`` implementation.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, Decodable {
    ///     static let databaseDataDecodingStrategy = DatabaseDataDecodingStrategy.custom { dbValue
    ///         guard let base64Data = Data.fromDatabaseValue(dbValue) else {
    ///             return nil
    ///         }
    ///         return Data(base64Encoded: base64Data)
    ///     }
    ///
    ///     // Decoded from both database base64 strings and blobs
    ///     var myData: Data
    /// }
    /// ```
    static var databaseDataDecodingStrategy: DatabaseDataDecodingStrategy { get }

    /// The strategy for decoding `Date` columns.
    ///
    /// This property is dedicated to ``FetchableRecord`` types that also
    /// conform to the standard `Decodable` protocol and use the default
    /// ``init(row:)-4ptlh`` implementation.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, Decodable {
    ///     static let databaseDateDecodingStrategy = DatabaseDateDecodingStrategy.timeIntervalSince1970
    ///
    ///     // Decoded from an epoch timestamp
    ///     var creationDate: Date
    /// }
    /// ```
    static var databaseDateDecodingStrategy: DatabaseDateDecodingStrategy { get }
    
    /// The strategy for converting column names to coding keys.
    ///
    /// This property is dedicated to ``FetchableRecord`` types that also
    /// conform to the standard `Decodable` protocol and use the default
    /// ``init(row:)-4ptlh`` implementation.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, Decodable {
    ///     static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    ///
    ///     // Decoded from the 'player_id' column
    ///     var playerID: String
    /// }
    /// ```
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { get }
}

extension FetchableRecord {
    /// Contextual information made available to the
    /// `Decodable.init(from:)` initializer.
    ///
    /// The default implementation returns an empty dictionary.
    public static var databaseDecodingUserInfo: [CodingUserInfoKey: Any] {
        [:]
    }
    
    /// Returns the `JSONDecoder` that decodes the value for a given column.
    ///
    /// The default implementation returns a `JSONDecoder` with the
    /// following properties:
    ///
    /// - `dataDecodingStrategy`: `.base64`
    /// - `dateDecodingStrategy`: `.millisecondsSince1970`
    /// - `nonConformingFloatDecodingStrategy`: `.throw`
    public static func databaseJSONDecoder(for column: String) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .base64
        decoder.dateDecodingStrategy = .millisecondsSince1970
        decoder.nonConformingFloatDecodingStrategy = .throw
        decoder.userInfo = databaseDecodingUserInfo
        return decoder
    }
    
    /// The default strategy for decoding `Data` columns is
    /// ``DatabaseDataDecodingStrategy/deferredToData``.
    public static var databaseDataDecodingStrategy: DatabaseDataDecodingStrategy {
        .deferredToData
    }
    
    /// The default strategy for decoding `Date` columns is
    /// ``DatabaseDateDecodingStrategy/deferredToDate``.
    public static var databaseDateDecodingStrategy: DatabaseDateDecodingStrategy {
        .deferredToDate
    }
    
    /// The default strategy for converting column names to coding keys is
    /// ``DatabaseColumnDecodingStrategy/useDefaultKeys``.
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy {
        .useDefaultKeys
    }
}

extension FetchableRecord {
    
    // MARK: Fetching From Prepared Statement
    
    /// Returns a cursor over records fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let players = try Player.fetchCursor(statement, arguments: [lastName])
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> RecordCursor<Self>
    {
        try RecordCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of records fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let players = try Player.fetchAll(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> [Self]
    {
        try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single record fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ? LIMIT 1"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let player = try Player.fetchOne(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Self?
    {
        try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

extension FetchableRecord where Self: Hashable {
    /// Returns a set of records fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let players = try Player.fetchSet(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Self>
    {
        try Set(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
}

extension FetchableRecord {
    
    // MARK: Fetching From SQL
    
    /// Returns a cursor over records fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let players = try Player.fetchCursor(db, sql: sql, arguments: [lastName])
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> RecordCursor<Self>
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of records fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// let players = try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     return try Player.fetchAll(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> [Self]
    {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single record fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// let player = try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ? LIMIT 1"
    ///     return try Player.fetchOne(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Self?
    {
        try fetchOne(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension FetchableRecord where Self: Hashable {
    /// Returns a set of records fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// let players = try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     return try Player.fetchSet(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Self>
    {
        try fetchSet(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

extension FetchableRecord {
    
    // MARK: Fetching From FetchRequest
    
    /// Returns a cursor over records fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let players = try Player.fetchCursor(db, request)
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: some FetchRequest) throws -> RecordCursor<Self> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        precondition(request.supplementaryFetch == nil, "Not implemented: fetchCursor with supplementary fetch")
        return try fetchCursor(request.statement, adapter: request.adapter)
    }
    
    /// Returns an array of records fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let players = try Player.fetchAll(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: An array of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: some FetchRequest) throws -> [Self] {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        if let supplementaryFetch = request.supplementaryFetch {
            let rows = try Row.fetchAll(request.statement, adapter: request.adapter)
            try supplementaryFetch(db, rows, nil)
            return try rows.map(Self.init(row:))
        } else {
            return try fetchAll(request.statement, adapter: request.adapter)
        }
    }
    
    /// Returns a single record fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///
    ///     let player = try Player.fetchOne(db, request)
    /// }
    /// ```
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: An optional record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: some FetchRequest) throws -> Self? {
        let request = try request.makePreparedRequest(db, forSingleResult: true)
        if let supplementaryFetch = request.supplementaryFetch {
            guard let row = try Row.fetchOne(request.statement, adapter: request.adapter) else {
                return nil
            }
            try supplementaryFetch(db, [row], nil)
            return try .init(row: row)
        } else {
            return try fetchOne(request.statement, adapter: request.adapter)
        }
    }
}

extension FetchableRecord where Self: Hashable {
    /// Returns a set of records fetched from a fetch request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let players = try Player.fetchSet(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: A set of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(_ db: Database, _ request: some FetchRequest) throws -> Set<Self> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        if let supplementaryFetch = request.supplementaryFetch {
            let rows = try Row.fetchAll(request.statement, adapter: request.adapter)
            try supplementaryFetch(db, rows, nil)
            return try Set(rows.lazy.map(Self.init(row:)))
        } else {
            return try fetchSet(request.statement, adapter: request.adapter)
        }
    }
}


// MARK: - FetchRequest

extension FetchRequest where RowDecoder: FetchableRecord {
    
    // MARK: Fetching Records
    
    /// Returns a cursor over fetched records.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let players = try request.fetchCursor(db)
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RecordCursor<RowDecoder> {
        try RowDecoder.fetchCursor(db, self)
    }
    
    /// Returns an array of fetched records.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let players = try request.fetchAll(db)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: An array of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [RowDecoder] {
        try RowDecoder.fetchAll(db, self)
    }
    
    /// Returns a single record.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///
    ///     let player = try request.fetchOne(db)
    /// }
    /// ```
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: An optional record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> RowDecoder? {
        try RowDecoder.fetchOne(db, self)
    }
}

extension FetchRequest where RowDecoder: FetchableRecord & Hashable {
    /// Returns a set of fetched records.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///
    ///     // Query interface request
    ///     let request = Player.filter(Column("lastName") == lastName)
    ///
    ///     // SQL request
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let players = try request.fetchSet(db)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: a FetchRequest.
    /// - returns: A set of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<RowDecoder> {
        try RowDecoder.fetchSet(db, self)
    }
}

// MARK: - RecordCursor

/// A cursor of records.
///
/// A `RecordCursor` iterates all rows from a database request. Its
/// elements are the records decoded from each fetched row.
///
/// For example:
///
/// ```swift
/// try dbQueue.read { db in
///     let players: RecordCursor<Player> = try Player.fetchCursor(db, sql: "SELECT * FROM player")
///     while let player = try players.next() {
///         print(player.name)
///     }
/// }
/// ```
public final class RecordCursor<Record: FetchableRecord>: DatabaseCursor {
    public typealias Element = Record
    public let _statement: Statement
    public var _isDone = false
    @usableFromInline
    let _row: Row // Instantiated once, reused for performance
    
    init(statement: Statement, arguments: StatementArguments? = nil, adapter: (any RowAdapter)? = nil) throws {
        self._statement = statement
        _row = try Row(statement: statement).adapted(with: adapter, layout: statement)
        
        // Assume cursor is created for immediate iteration: reset and set arguments
        try statement.prepareExecution(withArguments: arguments)
    }
    
    deinit {
        // Statement reset fails when sqlite3_step has previously failed.
        // Just ignore reset error.
        try? _statement.reset()
    }
    
    @inlinable
    public func _element(sqliteStatement: SQLiteStatement) throws -> Record {
        try Record(row: _row)
    }
}

// MARK: - DatabaseDataDecodingStrategy

/// `DatabaseDataDecodingStrategy` specifies how `FetchableRecord` types that
/// also  adopt the standard `Decodable` protocol decode their
/// `Data` properties.
///
/// For example:
///
/// ```swift
/// struct Player: FetchableRecord, Decodable {
///     static let databaseDataDecodingStrategy = DatabaseDataDecodingStrategy.custom { dbValue
///         guard let base64Data = Data.fromDatabaseValue(dbValue) else {
///             return nil
///         }
///         return Data(base64Encoded: base64Data)
///     }
///
///     // Decoded from both database base64 strings and blobs
///     var myData: Data
/// }
/// ```
public enum DatabaseDataDecodingStrategy {
    /// Decodes `Data` columns from SQL blobs and UTF8 text.
    case deferredToData
    
    /// Decodes `Data` columns according to the user-provided function.
    ///
    /// If the database value does not contain a suitable value, the function
    /// must return nil (GRDB will interpret this nil result as a conversion
    /// error, and react accordingly).
    case custom((DatabaseValue) -> Data?)
}

// MARK: - DatabaseDateDecodingStrategy

/// `DatabaseDateDecodingStrategy` specifies how `FetchableRecord` types that
/// also  adopt the standard `Decodable` protocol decode their
/// `Date` properties.
///
/// For example:
///
///     struct Player: FetchableRecord, Decodable {
///         static let databaseDateDecodingStrategy = DatabaseDateDecodingStrategy.timeIntervalSince1970
///
///         var name: String
///         var registrationDate: Date // decoded from epoch timestamp
///     }
public enum DatabaseDateDecodingStrategy {
    /// The strategy that uses formatting from the Date structure.
    ///
    /// It decodes numeric values as a number of seconds since Epoch
    /// (midnight UTC on January 1st, 1970).
    ///
    /// It decodes strings in the following formats, assuming UTC time zone.
    /// Missing components are assumed to be zero:
    ///
    /// - `YYYY-MM-DD`
    /// - `YYYY-MM-DD HH:MM`
    /// - `YYYY-MM-DD HH:MM:SS`
    /// - `YYYY-MM-DD HH:MM:SS.SSS`
    /// - `YYYY-MM-DDTHH:MM`
    /// - `YYYY-MM-DDTHH:MM:SS`
    /// - `YYYY-MM-DDTHH:MM:SS.SSS`
    case deferredToDate
    
    /// Decodes numeric values as a number of seconds between the date and
    /// midnight UTC on 1 January 2001
    case timeIntervalSinceReferenceDate
    
    /// Decodes numeric values as a number of seconds between the date and
    /// midnight UTC on 1 January 1970
    case timeIntervalSince1970
    
    /// Decodes numeric values as a number of milliseconds between the date and
    /// midnight UTC on 1 January 1970
    case millisecondsSince1970
    
    /// Decodes dates according to the ISO 8601 standards
    case iso8601
    
    /// Decodes a String, according to the provided formatter
    case formatted(DateFormatter)
    
    /// Decodes according to the user-provided function.
    ///
    /// If the database value  does not contain a suitable value, the function
    /// must return nil (GRDB will interpret this nil result as a conversion
    /// error, and react accordingly).
    case custom((DatabaseValue) -> Date?)
}

// MARK: - DatabaseColumnDecodingStrategy

/// `DatabaseColumnDecodingStrategy` specifies how `FetchableRecord` types that
/// also adopt the standard `Decodable` protocol look for the database columns
/// that match their coding keys.
///
/// For example:
///
///     struct Player: FetchableRecord, Decodable {
///         static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
///
///         // Decoded from the player_id column
///         var playerID: Int
///     }
public enum DatabaseColumnDecodingStrategy {
    /// A key decoding strategy that doesn’t change key names during decoding.
    case useDefaultKeys
    
    /// A key decoding strategy that converts snake-case keys to camel-case keys.
    case convertFromSnakeCase
    
    /// A key decoding strategy defined by the closure you supply.
    case custom((String) -> CodingKey)
    
    func key<K: CodingKey>(forColumn column: String) -> K? {
        switch self {
        case .useDefaultKeys:
            return K(stringValue: column)
        case .convertFromSnakeCase:
            return K(stringValue: Self._convertFromSnakeCase(column))
        case let .custom(key):
            return K(stringValue: key(column).stringValue)
        }
    }
    
    // Copied straight from
    // https://github.com/apple/swift-corelibs-foundation/blob/8d6398d76eaf886a214e0bb2bd7549d968f7b40e/Sources/Foundation/JSONDecoder.swift#L103
    static func _convertFromSnakeCase(_ stringKey: String) -> String {
        //===----------------------------------------------------------------------===//
        //
        // This function is part of the Swift.org open source project
        //
        // Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
        // Licensed under Apache License v2.0 with Runtime Library Exception
        //
        // See https://swift.org/LICENSE.txt for license information
        // See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
        //
        //===----------------------------------------------------------------------===//
        guard !stringKey.isEmpty else { return stringKey }

        // Find the first non-underscore character
        guard let firstNonUnderscore = stringKey.firstIndex(where: { $0 != "_" }) else {
            // Reached the end without finding an _
            return stringKey
        }

        // Find the last non-underscore character
        var lastNonUnderscore = stringKey.index(before: stringKey.endIndex)
        while lastNonUnderscore > firstNonUnderscore && stringKey[lastNonUnderscore] == "_" {
            stringKey.formIndex(before: &lastNonUnderscore)
        }

        let keyRange = firstNonUnderscore...lastNonUnderscore
        let leadingUnderscoreRange = stringKey.startIndex..<firstNonUnderscore
        let trailingUnderscoreRange = stringKey.index(after: lastNonUnderscore)..<stringKey.endIndex

        let components = stringKey[keyRange].split(separator: "_")
        let joinedString: String
        if components.count == 1 {
            // No underscores in key, leave the word as is - maybe already camel cased
            joinedString = String(stringKey[keyRange])
        } else {
            joinedString = ([components[0].lowercased()] + components[1...].map { $0.capitalized }).joined()
        }

        // Do a cheap isEmpty check before creating and appending potentially empty strings
        let result: String
        if leadingUnderscoreRange.isEmpty && trailingUnderscoreRange.isEmpty {
            result = joinedString
        } else if !leadingUnderscoreRange.isEmpty && !trailingUnderscoreRange.isEmpty {
            // Both leading and trailing underscores
            result = String(stringKey[leadingUnderscoreRange])
                + joinedString
                + String(stringKey[trailingUnderscoreRange])
        } else if !leadingUnderscoreRange.isEmpty {
            // Just leading
            result = String(stringKey[leadingUnderscoreRange]) + joinedString
        } else {
            // Just trailing
            result = joinedString + String(stringKey[trailingUnderscoreRange])
        }
        return result
    }
}
