extension DatabaseReader {
    /// Prints the results of all statements in the provided SQL.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Prints
    /// // 1|Arthur|500
    /// // 2|Barbara|1000
    /// dbQueue.dumpSQL("SELECT * FROM player ORDER BY id")
    /// ```
    ///
    /// - Parameters:
    ///   - sql: The executed SQL.
    ///   - format: The output format.
    ///   - stream: A stream for text output, which directs output to the
    ///     console by default.
    public func dumpSQL(
        _ sql: SQL,
        format: some DumpFormat = .debug(),
        to stream: (any TextOutputStream)? = nil)
    throws
    {
        try unsafeReentrantRead { db in
            try db.dumpSQL(sql, format: format, to: stream)
        }
    }
    
    /// Prints the results of a request.
    ///
    /// For example:
    ///
    /// ```swift
    /// // Prints
    /// // 1|Arthur|500
    /// // 2|Barbara|1000
    /// dbQueue.dumpRequest(Player.orderByPrimaryKey())
    /// ```
    ///
    /// - Parameters:
    ///   - request : The executed request.
    ///   - format: The output format.
    ///   - stream: A stream for text output, which directs output to the
    ///     console by default.
    public func dumpRequest(
        _ request: some FetchRequest,
        format: some DumpFormat = .debug(),
        to stream: (any TextOutputStream)? = nil)
    throws
    {
        try unsafeReentrantRead { db in
            try db.dumpRequest(request, format: format, to: stream)
        }
    }
    
    /// Prints the contents of the provided tables and views.
    ///
    /// For example:
    ///
    /// ```swift
    /// // player
    /// // 1|Arthur|500
    /// // 2|Barbara|1000
    /// //
    /// // team
    /// // 1|Red
    /// // 2|Blue
    /// dbQueue.dumpTables(["player", "team"])
    /// ```
    ///
    /// - Parameters:
    ///   - tables: The table names.
    ///   - format: The output format.
    ///   - tableHeader: Options for printing table names.
    ///   - stableOrder: A boolean value that controls the ordering of
    ///     rows fetched from views. If false (the default), rows are
    ///     printed in the order specified by the view (which may be
    ///     undefined). It true, outputted rows are always printed in the
    ///     same stable order. The purpose of this stable order is to make
    ///     the output suitable for testing.
    ///   - stream: A stream for text output, which directs output to the
    ///     console by default.
    public func dumpTables(
        _ tables: [String],
        format: some DumpFormat = .debug(),
        tableHeader: DumpTableHeaderOptions = .automatic,
        stableOrder: Bool = false,
        to stream: (any TextOutputStream)? = nil)
    throws
    {
        try unsafeReentrantRead { db in
            try db.dumpTables(
                tables,
                format: format,
                tableHeader: tableHeader,
                stableOrder: stableOrder,
                to: stream)
        }
    }
    
    /// Prints the contents of the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// dbQueue.dumpContent()
    /// ```
    ///
    /// This prints the database schema as well as the content of all
    /// tables. For example:
    ///
    /// ```
    /// sqlite_master
    /// CREATE TABLE player (id INTEGER PRIMARY KEY, name TEXT, score INTEGER)
    ///
    /// player
    /// 1,'Arthur',500
    /// 2,'Barbara',1000
    /// ```
    ///
    /// > Note: Internal SQLite and GRDB schema objects are not recorded
    /// > (those with a name that starts with "sqlite_" or "grdb_").
    /// >
    /// > [Shadow tables](https://www.sqlite.org/vtab.html#xshadowname) are
    /// > not recorded, starting SQLite 3.37+.
    ///
    /// - Parameters:
    ///   - format: The output format.
    ///   - stream: A stream for text output, which directs output to the
    ///     console by default.
    public func dumpContent(
        format: some DumpFormat = .debug(),
        to stream: (any TextOutputStream)? = nil)
    throws
    {
        try unsafeReentrantRead { db in
            try db.dumpContent(format: format, to: stream)
        }
    }
}
