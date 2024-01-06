import Foundation

// MARK: - Dump

extension Database {
    /// Prints the results of all statements in the provided SQL.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     // Prints
    ///     // 1|Arthur|500
    ///     // 2|Barbara|1000
    ///     db.dumpSQL("SELECT * FROM player ORDER BY id")
    /// }
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
        var dumpStream = DumpStream(stream)
        try _dumpSQL(sql, format: format, to: &dumpStream)
    }
    
    /// Prints the results of a request.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     // Prints
    ///     // 1|Arthur|500
    ///     // 2|Barbara|1000
    ///     db.dumpRequest(Player.orderByPrimaryKey())
    /// }
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
        var dumpStream = DumpStream(stream)
        try _dumpRequest(request, format: format, to: &dumpStream)
    }
    
    /// Prints the contents of the provided tables and views.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     // player
    ///     // 1|Arthur|500
    ///     // 2|Barbara|1000
    ///     //
    ///     // team
    ///     // 1|Red
    ///     // 2|Blue
    ///     db.dumpTables(["player", "team"])
    /// }
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
        var dumpStream = DumpStream(stream)
        try _dumpTables(
            tables,
            format: format,
            tableHeader: tableHeader,
            stableOrder: stableOrder,
            to: &dumpStream)
    }
    
    /// Prints the contents of the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     db.dumpContent()
    /// }
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
        var dumpStream = DumpStream(stream)
        try _dumpContent(format: format, to: &dumpStream)
    }
}

// MARK: -

extension Database {
    func _dumpStatements(
        _ statements: some Cursor<Statement>,
        format: some DumpFormat,
        to stream: inout DumpStream)
    throws
    {
        while let statement = try statements.next() {
            var stepFormat = format
            let cursor = try statement.makeCursor()
            while try cursor.next() != nil {
                try stepFormat.writeRow(self, statement: statement, to: &stream)
            }
            stepFormat.finalize(self, statement: statement, to: &stream)
        }
    }
    
    func _dumpSQL(
        _ sql: SQL,
        format: some DumpFormat,
        to stream: inout DumpStream)
    throws
    {
        try _dumpStatements(allStatements(literal: sql), format: format, to: &stream)
    }
    
    func _dumpRequest(
        _ request: some FetchRequest,
        format: some DumpFormat,
        to stream: inout DumpStream)
    throws
    {
        let preparedRequest = try request.makePreparedRequest(self, forSingleResult: false)
        try _dumpStatements(AnyCursor([preparedRequest.statement]), format: format, to: &stream)
        
        if let supplementaryFetch = preparedRequest.supplementaryFetch {
            let rows = try Row.fetchAll(self, request)
            try withoutActuallyEscaping(
                { request, keyPath in
                    stream.write("\n")
                    stream.writeln(keyPath.joined(separator: "."))
                    try self._dumpRequest(request, format: format, to: &stream)
                },
                do: { willExecuteSupplementaryRequest in
                    try supplementaryFetch(self, rows, willExecuteSupplementaryRequest)
                })
        }
    }
    
    func _dumpTables(
        _ tables: [String],
        format: some DumpFormat,
        tableHeader: DumpTableHeaderOptions,
        stableOrder: Bool,
        to stream: inout DumpStream)
    throws
    {
        let header: Bool
        switch tableHeader {
        case .always: header = true
        case .automatic: header = tables.count > 1
        }
        
        var first = true
        for table in tables {
            if first {
                first = false
            } else {
                stream.write("\n")
            }
            
            if header {
                stream.writeln(table)
            }
            
            if try tableExists(table) {
                // Always sort tables by primary key
                try _dumpRequest(Table(table).orderByPrimaryKey(), format: format, to: &stream)
            } else if stableOrder {
                // View with stable order
                try _dumpRequest(Table(table).all().withStableOrder(), format: format, to: &stream)
            } else {
                // Use view ordering, if any (no guarantee of stable order).
                try _dumpRequest(Table(table).all(), format: format, to: &stream)
            }
        }
    }
    
    func _dumpContent(
        format: some DumpFormat,
        to stream: inout DumpStream)
    throws
    {
        stream.writeln("sqlite_master")
        let sqlRows = try Row.fetchAll(self, sql: """
            SELECT sql || ';', name
            FROM sqlite_master
            WHERE sql IS NOT NULL
            ORDER BY
              tbl_name COLLATE NOCASE,
              CASE type WHEN 'table' THEN 'a' WHEN 'index' THEN 'aa' ELSE type END,
              name COLLATE NOCASE,
              sql
            """)
        for row in sqlRows {
            let name: String = row[1]
            if try ignoresObject(named: name) {
                continue
            }
            stream.writeln(row[0])
        }
        
        let tables = try String
            .fetchAll(self, sql: """
                SELECT name
                FROM sqlite_master
                WHERE type = 'table'
                ORDER BY name COLLATE NOCASE
                """)
            .filter {
                try !ignoresObject(named: $0)
            }
        if tables.isEmpty { return }
        stream.write("\n")
        try _dumpTables(tables, format: format, tableHeader: .always, stableOrder: true, to: &stream)
    }
    
    private func ignoresObject(named name: String) throws -> Bool {
        if Database.isSQLiteInternalTable(name) { return true }
        if Database.isGRDBInternalTable(name) { return true }
        if try isShadowTable(name) { return true }
        return false
    }
    
    private func isShadowTable(_ tableName: String) throws -> Bool {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        // Maybe SQLCipher is too old: check actual version
        if sqlite3_libversion_number() >= 3037000 {
            guard let table = try table(tableName) else {
                // Not a table
                return false
            }
            return table.kind == .shadow
        }
#else
        if #available(iOS 15.4, macOS 12.4, tvOS 15.4, watchOS 8.5, *) { // SQLite 3.37+
            guard let table = try table(tableName) else {
                // Not a table
                return false
            }
            return table.kind == .shadow
        }
#endif
        // Don't know
        return false
    }
}

/// Options for printing table names.
public enum DumpTableHeaderOptions {
    /// Table names are only printed when several tables are printed.
    case automatic

    /// Table names are always printed.
    case always
}
