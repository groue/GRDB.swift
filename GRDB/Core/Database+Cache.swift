extension Database {
    func withCache<T>(atPath path: String, execute: () throws -> T) throws -> T {
        GRDBPrecondition(attachedCache == nil, "Database is already cached.")
        
        return try throwingFirstError {
            attachedCache = AttachedCache(
                schema: .attached("cache"),
                statementCache: StatementCache(database: self))
            try self.execute(literal: "ATTACH DATABASE \(path) AS cache")
            return try execute()
        } finally: {
            attachedCache = nil
            try self.execute(sql: "DETACH DATABASE cache")
        }
    }
}

extension Statement {
    /// Returns a statement ready for iterating the results of this statement
    /// with a DatabaseCursor.
    ///
    /// The result is not the same statement as the receiver if we cache the
    /// statement's results.
    func databaseCursorStatement(with arguments: StatementArguments?) throws -> Statement {
        // Should we cache statement results and return a new statement on the cached values?
        guard
            // Don't cache until we were instructed to.
            let attachedCache = database.attachedCache,
            
            // Only cache read-only statements.
            isReadonly,
            
            // Only cache statements that access user tables.
            databaseRegion
                .filteringTables({ !Database.isSQLiteInternalTable($0) && !Database.isGRDBInternalTable($0) })
                .isEmpty == false,
            
            // Only cache statements that can build a name for the cache table.
            let cacheTableName,
            
            // Only cache statements for which we can guarantee rowid ordering
            // without ambiguity.
            case let statementColumns = columnNames.map({ $0.lowercased() }),
            let rowid = ["rowid", "_rowid_", "oid"].first(where: { !statementColumns.contains($0) })
        else {
            // Don't cache: return self.
            // Reset before cursor iteration: the statement may be reused.
            try prepareExecution(withArguments: arguments)
            return self
        }
        
        // Cache the results if not done yet
        let cacheTable = Database.TableIdentifier(schemaID: attachedCache.schema, name: cacheTableName)
        try database.execute(sql: """
            CREATE TABLE IF NOT EXISTS \(cacheTable.quotedDatabaseIdentifier) AS \(sql)
            """, arguments: arguments ?? self.arguments)
        
        // Return a statement on the cached values, preserving the order of the
        // original rows.
        //
        // Quoting <https://sqlite.org/lang_createtable.html#create_table_as_select_statements>:
        //
        // > Tables created using CREATE TABLE AS are initially populated with
        // > the rows of data returned by the SELECT statement. Rows are
        // > assigned contiguously ascending rowid values, starting with 1, in
        // > the order that they are returned by the SELECT statement.
        let statement = try attachedCache.statementCache.statement("""
            SELECT * FROM \(cacheTable.quotedDatabaseIdentifier) ORDER BY \(rowid)
            """)
        // Reset before cursor iteration: the statement may be reused.
        try statement.reset()
        return statement
    }
}
