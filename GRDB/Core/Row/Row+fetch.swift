// MARK: - Fetching From Prepared Statement

extension Row {
    /// Returns a cursor over rows fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let rows = try Row.fetchCursor(statement, arguments: [lastName])
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``fetchAll(_:arguments:adapter:)`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
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
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> RowCursor
    {
        try RowCursor(statement: statement, arguments: arguments, adapter: adapter)
    }
    
    /// Returns an array of rows fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let rows = try Row.fetchAll(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> [Row]
    {
        // The cursor reuses a single mutable row. Return immutable copies.
        try Array(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
    }
    
    /// Returns a set of rows fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let rows = try Row.fetchSet(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Row>
    {
        // The cursor reuses a single mutable row. Return immutable copies.
        try Set(fetchCursor(statement, arguments: arguments, adapter: adapter).map { $0.copy() })
    }
    
    /// Returns a single row fetched from a prepared statement.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ? LIMIT 1"
    ///     let statement = try db.makeStatement(sql: sql)
    ///     let row = try Row.fetchOne(statement, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - statement: The statement to run.
    ///     - arguments: Optional statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ statement: Statement,
        arguments: StatementArguments? = nil,
        adapter: (any RowAdapter)? = nil)
    throws -> Row?
    {
        let cursor = try fetchCursor(statement, arguments: arguments, adapter: adapter)
        // Keep cursor alive until we can copy the fetched row
        return try withExtendedLifetime(cursor) {
            try cursor.next().map { $0.copy() }
        }
    }
}

// MARK: - Fetching From SQL

extension Row {
    /// Returns a cursor over rows fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let rows = try Row.fetchCursor(db, sql: sql, arguments: [lastName])
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``fetchAll(_:sql:arguments:adapter:)`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
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
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> RowCursor
    {
        try fetchCursor(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns an array of rows fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let rows = try Row.fetchAll(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An array of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> [Row]
    {
        try fetchAll(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a set of rows fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ?"
    ///     let rows = try Row.fetchSet(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: A set of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Set<Row>
    {
        try fetchSet(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
    
    /// Returns a single row fetched from an SQL query.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let sql = "SELECT * FROM player WHERE lastName = ? LIMIT 1"
    ///     let row = try Row.fetchOne(db, sql: sql, arguments: [lastName])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - sql: An SQL string.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: (any RowAdapter)? = nil)
    throws -> Row?
    {
        try fetchOne(db, SQLRequest(sql: sql, arguments: arguments, adapter: adapter))
    }
}

// MARK: - Fetching From FetchRequest

extension Row {
    /// Returns a cursor over rows fetched from a fetch request.
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
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let rows = try Row.fetchCursor(db, request)
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``fetchAll(_:_:)`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, _ request: some FetchRequest) throws -> RowCursor {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        precondition(request.supplementaryFetch == nil, "Not implemented: fetchCursor with supplementary fetch")
        return try fetchCursor(request.statement, adapter: request.adapter)
    }
    
    /// Returns an array of rows fetched from a fetch request.
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
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let rows = try Row.fetchAll(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An array of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, _ request: some FetchRequest) throws -> [Row] {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        let rows = try fetchAll(request.statement, adapter: request.adapter)
        try request.supplementaryFetch?(db, rows, nil)
        return rows
    }
    
    /// Returns a set of rows fetched from a fetch request.
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
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///
    ///     let rows = try Row.fetchSet(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: A set of rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(_ db: Database, _ request: some FetchRequest) throws -> Set<Row> {
        let request = try request.makePreparedRequest(db, forSingleResult: false)
        if let supplementaryFetch = request.supplementaryFetch {
            let rows = try fetchAll(request.statement, adapter: request.adapter)
            try supplementaryFetch(db, rows, nil)
            return Set(rows)
        } else {
            return try fetchSet(request.statement, adapter: request.adapter)
        }
    }
    
    /// Returns a single row fetched from a fetch request.
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
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///
    ///     let row = try Row.fetchOne(db, request)
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - request: A FetchRequest.
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, _ request: some FetchRequest) throws -> Row? {
        let request = try request.makePreparedRequest(db, forSingleResult: true)
        guard let row = try fetchOne(request.statement, adapter: request.adapter) else {
            return nil
        }
        try request.supplementaryFetch?(db, [row], nil)
        return row
    }
}

// MARK: FetchRequest+Row

extension FetchRequest<Row> {
    /// Returns a cursor over fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchCursor(db)
    ///     while let row = try rows.next() {
    ///         let id: Int64 = row["id"]
    ///         let name: String = row["name"]
    ///     }
    /// }
    /// ```
    ///
    /// Fetched rows are reused during the cursor iteration: don't turn a row
    /// cursor into an array with `Array(rows)` since you would not get the
    /// distinct rows you expect.
    /// Use ``FetchRequest/fetchAll(_:)-7p809`` instead.
    ///
    /// For the same reason, make sure you make a copy whenever you extract a
    /// row for later use: `row.copy()`.
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``RowCursor`` over fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchCursor(_ db: Database) throws -> RowCursor {
        try Row.fetchCursor(db, self)
    }
    
    /// Returns an array of fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchAll(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: An array of fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchAll(_ db: Database) throws -> [Row] {
        try Row.fetchAll(db, self)
    }
    
    /// Returns a set of fetched rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName)
    ///         """
    ///     let rows = try request.fetchSet(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: A set of fetched rows.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchSet(_ db: Database) throws -> Set<Row> {
        try Row.fetchSet(db, self)
    }
    
    /// Returns a single row.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let lastName = "O'Reilly"
    ///     let request: SQLRequest<Row> = """
    ///         SELECT * FROM player WHERE lastName = \(lastName) LIMIT 1
    ///         """
    ///     let rows = try request.fetchOne(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - returns: An optional row.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func fetchOne(_ db: Database) throws -> Row? {
        try Row.fetchOne(db, self)
    }
}
