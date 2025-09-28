// Import C SQLite functions
#if SWIFT_PACKAGE
import GRDBSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !SQLITE_HAS_CODEC
import SQLite3
#endif

extension Database {
    /// A cache for the available database schemas.
    struct SchemaCache {
        /// The available schema identifiers, in the order of SQLite resolution:
        /// temp, main, then attached databases.
        var schemaIDs: [DatabaseSchemaID]?
        
        /// The schema cache for each identifier.
        fileprivate var schemas: [DatabaseSchemaID: DatabaseSchemaCache] = [:]
        
        /// The schema cache for a given identifier
        subscript(schemaID: DatabaseSchemaID) -> DatabaseSchemaCache { // internal so that it can be tested
            get {
                schemas[schemaID] ?? DatabaseSchemaCache()
            }
            set {
                schemas[schemaID] = newValue
            }
        }
        
        mutating func clear() {
            schemaIDs = nil
            schemas.removeAll()
        }
    }
    
    // MARK: - Database Schema
    
    /// Executes the wrapped statements with the provided schema source.
    public func withSchemaSource<T>(
        _ schemaSource: (any DatabaseSchemaSource)?,
        execute block: () throws -> T
    ) rethrows -> T {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        let previousSchemaSource = self.schemaSource
        self.schemaSource = schemaSource
        defer {
            self.schemaSource = previousSchemaSource
            clearSchemaCache() // Clear from cache the information loaded from the new schema source.
        }
        
        clearSchemaCache() // Clear from cache the information loaded from the previous schema source.
        return try block()
    }
    
    /// Returns the current schema version (`PRAGMA schema_version`).
    ///
    /// For example:
    ///
    /// ```swift
    /// let version = try dbQueue.read { db in
    ///     try db.schemaVersion()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/pragma.html#pragma_schema_version>
    public func schemaVersion() throws -> Int32 {
        try Int32.fetchOne(internalCachedStatement(sql: "PRAGMA schema_version"))!
    }
    
    /// Clears the database schema cache.
    ///
    /// If the database schema is modified by another SQLite connection to the
    /// same database file, your application may need to call this method in
    /// order to avoid undesired consequences.
    public func clearSchemaCache() {
        // TODO: can't we automatically clear the cache for writer connection,
        // just as we do for DatabasePool reader connections?
        
        SchedulingWatchdog.preconditionValidQueue(self)
        schemaCache.clear()
        
        // We also clear statement cache despite the automatic statement
        // recompilation (see https://www.sqlite.org/c3ref/prepare.html)
        // because the automatic statement recompilation only happens a
        // limited number of times (`SQLITE_MAX_SCHEMA_RETRY`).
        internalStatementCache.clear()
        publicStatementCache.clear()
    }
    
    /// Clears the database schema cache if the database schema has changed
    /// since this method was last called.
    func clearSchemaCacheIfNeeded() throws {
        // `PRAGMA schema_version` fetches a 4-bytes integer (Int32), stored
        // at offset 40 of the database header:
        // <https://sqlite.org/pragma.html#pragma_schema_version>
        // <https://sqlite.org/fileformat2.html#database_header>
        let schemaVersion = try self.schemaVersion()
        if lastSchemaVersion != schemaVersion {
            lastSchemaVersion = schemaVersion
            clearSchemaCache()
        }
    }
    
    /// Fetches the list of database schemas, in the order of SQLite
    /// resolution: temp, main, then attached databases (as documented at
    /// <https://www.sqlite.org/lang_naming.html>).
    func fetchSchemaIdentifiers() throws -> [DatabaseSchemaID] {
        if let schemaIDs = schemaCache.schemaIDs {
            return schemaIDs
        }
        
        var schemaIDs = try Array(Row
            .fetchCursor(self, sql: "PRAGMA database_list")
            .map { row -> DatabaseSchemaID in
                DatabaseSchemaID(name: row[1] as String)
            })
        
        // Temp schema shadows all other schemas: put it first
        if let tempIdx = schemaIDs.firstIndex(of: .temp) {
            schemaIDs.swapAt(tempIdx, 0)
        }
        
        schemaCache.schemaIDs = schemaIDs
        return schemaIDs
    }
    
    /// The `DatabaseSchemaID` named `schemaName`, if it exists.
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or
    /// if no such schema exists.
    private func schemaIdentifier(named schemaName: String) throws -> DatabaseSchemaID {
        let schemaIDs = try fetchSchemaIdentifiers()
        if let schemaID = schemaIDs.first(where: { $0.name.lowercased() == schemaName.lowercased() }) {
            return schemaID
        } else {
            throw DatabaseError.noSuchSchema(schemaName)
        }
    }
    
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
    /// Returns information about a table or a view
    func table(_ tableName: String) throws -> TableInfo? {
        for schemaID in try fetchSchemaIdentifiers() {
            if let result = try table(for: DatabaseObjectID(name: tableName, schemaID: schemaID)) {
                return result
            }
        }
        return nil
    }
    
    /// Returns information about a table or a view
    func table(for table: DatabaseObjectID) throws -> TableInfo? {
        // Maybe SQLCipher is too old: check actual version
        GRDBPrecondition(sqlite3_libversion_number() >= 3037000, "SQLite 3.37+ required")
        return try _table(for: table)
    }
#else
    /// Returns information about a table or a view
    @available(iOS 15.4, macOS 12.4, tvOS 15.4, watchOS 8.5, *) // SQLite 3.37+
    func table(_ tableName: String) throws -> TableInfo? {
        for schemaID in try fetchSchemaIdentifiers() {
            if let result = try table(for: DatabaseObjectID(name: tableName, schemaID: schemaID)) {
                return result
            }
        }
        return nil
    }
    
    /// Returns information about a table or a view
    @available(iOS 15.4, macOS 12.4, tvOS 15.4, watchOS 8.5, *) // SQLite 3.37+
    func table(for table: DatabaseObjectID) throws -> TableInfo? {
        try _table(for: table)
    }
#endif
    /// Returns information about a table or a view
    private func _table(for table: DatabaseObjectID) throws -> TableInfo? {
        assert(sqlite3_libversion_number() >= 3037000, "SQLite 3.37+ required")
        SchedulingWatchdog.preconditionValidQueue(self)
        
        if let tableInfo = schemaCache[table.schemaID].table(table.name) {
            return tableInfo.value
        }
        
        guard let tableInfo = try TableInfo
            .fetchOne(self, sql: "PRAGMA \(table.schemaID.name).table_list(\(table.name.quotedDatabaseIdentifier))")
        else {
            // table does not exist
            schemaCache[table.schemaID].set(tableInfo: .missing, forTable: table.name)
            return nil
        }
        
        schemaCache[table.schemaID].set(tableInfo: .value(tableInfo), forTable: table.name)
        return tableInfo
    }
    
    /// Returns whether a table exists
    ///
    /// When `schemaName` is not specified, the result is true if any known
    /// schema contains the table.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     if try db.tableExists("player") { ... }
    ///     if try db.tableExists("player", in: "main") { ... }
    ///     if try db.tableExists("player", in: "temp") { ... }
    ///     if try db.tableExists("player", in: "attached") { ... }
    /// }
    /// ```
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or
    /// if the specified schema does not exist
    public func tableExists(_ name: String, in schemaName: String? = nil) throws -> Bool {
        if let schemaName {
            return try exists(type: .table, name: name, in: schemaName)
        }
        
        return try fetchSchemaIdentifiers().contains {
            try exists(type: .table, name: name, in: $0)
        }
    }
    
    private func tableExists(_ table: DatabaseObjectID) throws -> Bool {
        try exists(type: .table, name: table.name, in: table.schemaID)
    }
    
    /// Returns whether a table is an internal SQLite table.
    ///
    /// Those are tables whose name begins with `sqlite_` and `pragma_`.
    ///
    /// For more information, see <https://www.sqlite.org/fileformat2.html>
    public static func isSQLiteInternalTable(_ tableName: String) -> Bool {
        // https://www.sqlite.org/fileformat2.html#internal_schema_objects
        // > The names of internal schema objects always begin with "sqlite_"
        // > and any table, index, view, or trigger whose name begins with
        // > "sqlite_" is an internal schema object. SQLite prohibits
        // > applications from creating objects whose names begin with
        // > "sqlite_".
        tableName.starts(with: "sqlite_") || tableName.starts(with: "pragma_")
    }
    
    /// Returns whether a table is an internal GRDB table.
    ///
    /// Those are tables whose name begins with `grdb_`.
    public static func isGRDBInternalTable(_ tableName: String) -> Bool {
        tableName.starts(with: "grdb_")
    }
    
    /// Returns whether a view exists, in the main or temp schema, or in an
    /// attached database.
    ///
    /// When `schemaName` is not specified, the result is true if any known
    /// schema contains the table.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     if try db.viewExists("player") { ... }
    ///     if try db.viewExists("player", in: "main") { ... }
    ///     if try db.viewExists("player", in: "temp") { ... }
    ///     if try db.viewExists("player", in: "attached") { ... }
    /// }
    /// ```
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or
    /// if the specified schema does not exist
    public func viewExists(_ name: String, in schemaName: String? = nil) throws -> Bool {
        if let schemaName {
            return try exists(type: .view, name: name, in: schemaName)
        }
        
        return try fetchSchemaIdentifiers().contains {
            try exists(type: .view, name: name, in: $0)
        }
    }
    
    /// Returns whether a trigger exists, in the main or temp schema, or in an
    /// attached database.
    ///
    /// When `schemaName` is not specified, the result is true if any known
    /// schema contains the table.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     if try db.triggerExists("on_player_update") { ... }
    ///     if try db.triggerExists("on_player_update", in: "main") { ... }
    ///     if try db.triggerExists("on_player_update", in: "temp") { ... }
    ///     if try db.triggerExists("on_player_update", in: "attached") { ... }
    /// }
    /// ```
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or
    /// if the specified schema does not exist
    public func triggerExists(_ name: String, in schemaName: String? = nil) throws -> Bool {
        if let schemaName {
            return try exists(type: .trigger, name: name, in: schemaName)
        }
        
        return try fetchSchemaIdentifiers().contains {
            try exists(type: .trigger, name: name, in: $0)
        }
    }
    
    /// Checks if an entity exists in a given schema
    ///
    /// This is checking for the existence of the entity specified by
    /// `type` and `name`. It is assumed that the existence of a schema
    /// named `schemaName` is already known and will throw an error if it
    /// cannot be found.
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or
    /// if the specified schema does not exist
    private func exists(type: SchemaObjectType, name: String, in schemaName: String) throws -> Bool {
        let schemaIDs = try fetchSchemaIdentifiers()
        if let schemaID = schemaIDs.first(where: { $0.name.lowercased() == schemaName.lowercased() }) {
            return try exists(type: type, name: name, in: schemaID)
        } else {
            throw DatabaseError.noSuchSchema(schemaName)
        }
    }
    
    private func exists(type: SchemaObjectType, name: String, in schemaID: DatabaseSchemaID) throws -> Bool {
        // SQLite identifiers are case-insensitive, case-preserving:
        // http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html
        try schema(schemaID).containsObjectNamed(name, ofType: type)
    }
    
    /// The primary key for table named `tableName`.
    ///
    /// All tables have a primary key, even when it is not explicit. When a
    /// table has no explicit primary key, the result is the hidden
    /// "rowid" column.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let primaryKey = try db.primaryKey("player")
    ///     print(primaryKey.columns)
    /// }
    /// ```
    ///
    /// When `schemaName` is nil, known schemas are iterated in
    /// SQLite resolution order, and the first matching result is returned.
    /// For more information, see <https://www.sqlite.org/lang_naming.html>.
    ///
    /// Database views are supported, if the connection is configured with
    /// a schema source. See ``Configuration/schemaSource``.
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, if
    /// the specified schema does not exist, or if no such table exists in
    /// the main or temp schema, or in an attached database.
    public func primaryKey(_ tableName: String, in schemaName: String? = nil) throws -> PrimaryKeyInfo {
        if let schemaName {
            return try introspect(tableNamed: tableName, inSchemaNamed: schemaName, using: primaryKey(_:))
        }
        
        for schemaID in try fetchSchemaIdentifiers() {
            if let result = try primaryKey(DatabaseObjectID(name: tableName, schemaID: schemaID)) {
                return result
            }
        }
        
        if (try? viewExists(tableName, in: schemaName)) == true {
            throw DatabaseError(message: """
                database view \(tableName) has no primary key
                """)
        } else {
            throw DatabaseError.noSuchTable(tableName)
        }
    }
    
    /// Returns the name of the single-column primary key.
    ///
    /// A fatal error is raised if the primary key has several columns, or
    /// if `tableName` is the name of a database view that is not customized
    /// with the schemaSource.
    func filteringPrimaryKeyColumn(_ tableName: String) throws -> String {
        do {
            let primaryKey = try primaryKey(tableName)
            GRDBPrecondition(
                primaryKey.columns.count == 1,
                "Filtering by primary key requires a single-column primary key in the table '\(tableName)'")
            return primaryKey.columns[0]
        } catch let error as DatabaseError {
            // Maybe the user tries to filter a view by primary key,
            // as in <https://github.com/groue/GRDB.swift/issues/1648>.
            // In this case, raise a fatalError because this is a
            // programmer error which is very likely to be detected
            // during development.
            if case .SQLITE_ERROR = error.resultCode,
               (try? viewExists(tableName)) == true
            {
                throw DatabaseError(message: """
                    database view \(tableName) has no primary key
                    """)
            } else {
                throw error
            }
        }
    }
    
    /// Returns nil if table does not exist
    private func primaryKey(_ table: DatabaseObjectID) throws -> PrimaryKeyInfo? {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        if let primaryKey = schemaCache[table.schemaID].primaryKey(table.name) {
            return primaryKey.value
        }
        
        var primaryKey: PrimaryKeyInfo?
        
        if let schemaSource,
           try viewExists(table.name, in: table.schemaID.name),
           let primaryKeyColumns = try schemaSource.columnsForPrimaryKey(self, inView: table)
        {
            primaryKey = try fetchPrimitivePrimaryKey(forView: table, columns: primaryKeyColumns)
        }
        
        if primaryKey == nil {
            primaryKey = try fetchPrimitivePrimaryKey(forTable: table)
        }
        
        if let primaryKey {
            schemaCache[table.schemaID].set(primaryKey: .value(primaryKey), forTable: table.name)
            return primaryKey
        } else {
            schemaCache[table.schemaID].set(primaryKey: .missing, forTable: table.name)
            return nil
        }
    }
    
    /// Fetches the primary key for the database table identified
    /// by `table`, or returns nil if the database schema does not contain
    /// that table.
    ///
    /// This method relies entirely on SQLite schema introspection.
    func fetchPrimitivePrimaryKey(forTable table: DatabaseObjectID) throws -> PrimaryKeyInfo? {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        if try !tableExists(table) {
            // Only tables have a primary key. Views, CTE, etc. do not.
            return nil
        }
        
        // https://www.sqlite.org/pragma.html
        //
        // > PRAGMA database.table_info(table-name);
        // >
        // > This pragma returns one row for each column in the named table.
        // > Columns in the result set include the column name, data type,
        // > whether or not the column can be NULL, and the default value for
        // > the column. The "pk" column in the result set is zero for columns
        // > that are not part of the primary key, and is the index of the
        // > column in the primary key for columns that are part of the primary
        // > key.
        //
        // CREATE TABLE players (
        //   id INTEGER PRIMARY KEY,
        //   name TEXT,
        //   score INTEGER)
        //
        // PRAGMA table_info("players")
        //
        // cid | name  | type    | notnull | dflt_value | pk |
        // 0   | id    | INTEGER | 0       | NULL       | 1  |
        // 1   | name  | TEXT    | 0       | NULL       | 0  |
        // 2   | score | INTEGER | 0       | NULL       | 0  |
        guard let columns = try self.columns(in: table) else {
            // table does not exist
            return nil
        }
        
        let pkColumns = columns
            .filter { $0.primaryKeyIndex > 0 }
            .sorted { $0.primaryKeyIndex < $1.primaryKeyIndex }
        
        switch pkColumns.count {
        case 0:
            // No explicit primary key => primary key is the hidden rowID column
            return .hiddenRowID
            
        case 1:
            // Single column
            let pkColumn = pkColumns[0]
            
            // https://www.sqlite.org/lang_createtable.html:
            //
            // > With one exception noted below, if a rowid table has a primary
            // > key that consists of a single column and the declared type of
            // > that column is "INTEGER" in any mixture of upper and lower
            // > case, then the column becomes an alias for the rowid. Such a
            // > column is usually referred to as an "integer primary key".
            // > A PRIMARY KEY column only becomes an integer primary key if the
            // > declared type name is exactly "INTEGER". Other integer type
            // > names like "INT" or "BIGINT" or "SHORT INTEGER" or "UNSIGNED
            // > INTEGER" causes the primary key column to behave as an ordinary
            // > table column with integer affinity and a unique index, not as
            // > an alias for the rowid.
            // >
            // > The exception mentioned above is that if the declaration of a
            // > column with declared type "INTEGER" includes an "PRIMARY KEY
            // > DESC" clause, it does not become an alias for the rowid [...]
            //
            // FIXME: We ignore the exception, and consider all INTEGER primary
            // keys as aliases for the rowid:
            if pkColumn.type.uppercased() == "INTEGER" {
                return .rowID(pkColumn)
            } else {
                return try .regular([pkColumn], tableHasRowID: fetchTableHasRowID(table))
            }
            
        default:
            // Multi-columns primary key
            return try .regular(pkColumns, tableHasRowID: fetchTableHasRowID(table))
        }
    }
    
    /// Fetches a customized primary key for the database view identified
    /// by `view`.
    ///
    /// Nil is returned in the view does not exist, or if `columns` is empty.
    ///
    /// - precondition: If the view exists, columns must exist, must
    ///   identify a unique row, and must be not null.
    func fetchPrimitivePrimaryKey(
        forView view: DatabaseObjectID,
        columns: [String]
    ) throws -> PrimaryKeyInfo? {
        if columns.isEmpty {
            return nil
        }
        
        guard let infos = try fetchPrimitiveColumns(in: view) else {
            // View does not exist
            return nil
        }
        
        let pkInfos = columns.enumerated().map { index, column in
            guard var info = infos.first(where: { $0.name.lowercased() == column.lowercased() }) else {
                // The requested column does not exist in the database schema.
                // Is it a programmer error, or a runtime error?
                // Let's make it a programmer error to start with.
                fatalError("""
                    No such column in \(view.schemaID.viewNameInErrorMessages(view.name)): \(column)
                    """)
            }
            
            // Rewrite primaryKeyIndex, and use a 1-based index, as
            // documented in https://www.sqlite.org/pragma.html#pragma_table_info
            info.primaryKeyIndex = index + 1
            
            return info
        }
        
        return .regular(pkInfos, tableHasRowID: false /* views have no rowid */)
    }
    
    /// Returns whether the column identifies the rowid column
    func columnIsRowID(_ column: String, of tableName: String) throws -> Bool {
        let pk = try primaryKey(tableName)
        return pk.rowIDColumn == column || (pk.tableHasRowID && column.uppercased() == "ROWID")
    }
    
    /// Returns whether the table has a rowid column.
    ///
    /// - precondition: table exists.
    private func fetchTableHasRowID(_ table: DatabaseObjectID) throws -> Bool {
        // Prefer PRAGMA table_list if available
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        // Maybe SQLCipher is too old: check actual version
        if sqlite3_libversion_number() >= 3037000 {
            return try self.table(for: table)!.isWithoutRowIDTable == false
        }
#else
        if #available(iOS 15.4, macOS 12.4, tvOS 15.4, watchOS 8.5, *) { // SQLite 3.37+
            return try self.table(for: table)!.isWithoutRowIDTable == false
        }
#endif
        
        // To check if the table has a rowid, we compile a statement that
        // selects the `rowid` column. If compilation fails, we assume that the
        // table is WITHOUT ROWID. This is not a very robust test (users may
        // create WITHOUT ROWID tables with a `rowid` column), but nobody has
        // reported any problem yet.
        //
        // Since compilation may fail, we may feed the SQLite error log, and
        // users may wonder what are those errors. That's why we use a
        // distinctive alias (`checkWithoutRowidOptimization`), so that anyone
        // can search the GRDB code, find this documentation, and understand why
        // this query appears in the error log:
        // <https://github.com/groue/GRDB.swift/issues/945#issuecomment-804896196>
        //
        // We don't use `try makeStatement(sql:)` in order to avoid throwing an
        // error (this annoys users who set a breakpoint on Swift errors).
        let sql = "SELECT rowid AS checkWithoutRowidOptimization FROM \(table.quotedDatabaseIdentifier)"
        var statement: SQLiteStatement?
        let code = sqlite3_prepare_v2(sqliteConnection, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        return code == SQLITE_OK
    }
    
    /// The indexes on table named `tableName`.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let indexes = db.indexes(in: "player")
    ///     for index in indexes {
    ///         print(index.columns)
    ///     }
    /// }
    /// ```
    ///
    /// Only indexes on columns are returned. Indexes on expressions are
    /// not returned.
    ///
    /// SQLite does not define any index for INTEGER PRIMARY KEY columns:
    /// this method does not return any index that represents the
    /// primary key.
    ///
    /// If you want to know if a set of columns uniquely identifies a row,
    /// because the columns contain the primary key or a unique index, use
    /// ``table(_:hasUniqueKey:)``.
    ///
    /// When `schemaName` is nil, known schemas are iterated in
    /// SQLite resolution order, and the first matching result is returned.
    /// For more information, see <https://www.sqlite.org/lang_naming.html>.
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, if
    /// the specified schema does not exist, or if no such table or view
    /// with this name exists in the main or temp schema, or in an attached
    /// database.
    public func indexes(on tableName: String, in schemaName: String? = nil) throws -> [IndexInfo] {
        if let schemaName {
            return try introspect(tableNamed: tableName, inSchemaNamed: schemaName, using: indexes(on:))
        }
        
        for schemaID in try fetchSchemaIdentifiers() {
            if let result = try indexes(on: DatabaseObjectID(name: tableName, schemaID: schemaID)) {
                return result
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    /// Returns nil if table does not exist
    private func indexes(on table: DatabaseObjectID) throws -> [IndexInfo]? {
        if let indexes = schemaCache[table.schemaID].indexes(on: table.name) {
            return indexes.value
        }
        
        let indexes = try Row
            // [seq:0 name:"index" unique:0 origin:"c" partial:0]
            .fetchAll(self, sql: "PRAGMA \(table.schemaID.name).index_list(\(table.name.quotedDatabaseIdentifier))")
            .compactMap { row -> IndexInfo? in
                let indexName: String = row[1]
                let unique: Bool = row[2]
                let origin: IndexInfo.Origin = row[3]
                
                let indexInfoRows = try Row
                    // [seqno:0 cid:2 name:"column"]
                    .fetchAll(self, sql: """
                        PRAGMA \(table.schemaID.name).index_info(\(indexName.quotedDatabaseIdentifier))
                        """)
                    // Sort by rank
                    .sorted(by: { ($0[0] as Int) < ($1[0] as Int) })
                var columns: [String] = []
                for indexInfoRow in indexInfoRows {
                    guard let column = indexInfoRow[2] as String? else {
                        // https://sqlite.org/pragma.html#pragma_index_info
                        // > The name of the column being indexed is NULL if the
                        // > column is the rowid or an expression.
                        //
                        // IndexInfo does not support expressing such index.
                        // Maybe in a future GRDB version?
                        return nil
                    }
                    columns.append(column)
                }
                return IndexInfo(name: indexName, columns: columns, isUnique: unique, origin: origin)
            }
        
        if indexes.isEmpty {
            // PRAGMA index_list doesn't throw any error when table does
            // not exist. So let's check if table exists:
            if try tableExists(table) == false {
                schemaCache[table.schemaID].set(indexes: .missing, forTable: table.name)
                return nil
            }
        }
        
        schemaCache[table.schemaID].set(indexes: .value(indexes), forTable: table.name)
        return indexes
    }
    
    /// Returns whether a sequence of columns uniquely identifies a row.
    ///
    /// The result is true if and only if the primary key, or a unique index, is
    /// included in the sequence.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     // One table with one primary key (id)
    ///     // and a unique index (a, b):
    ///     //
    ///     // > CREATE TABLE t(id INTEGER PRIMARY KEY, a, b, c);
    ///     // > CREATE UNIQUE INDEX i ON t(a, b);
    ///     try db.table("t", hasUniqueKey: ["id"])                // true
    ///     try db.table("t", hasUniqueKey: ["a", "b"])            // true
    ///     try db.table("t", hasUniqueKey: ["b", "a"])            // true
    ///     try db.table("t", hasUniqueKey: ["c"])                 // false
    ///     try db.table("t", hasUniqueKey: ["id", "a"])           // true
    ///     try db.table("t", hasUniqueKey: ["id", "a", "b", "c"]) // true
    /// }
    /// ```
    public func table(
        _ tableName: String,
        hasUniqueKey columns: some Collection<String>
    ) throws -> Bool {
        try columnsForUniqueKey(columns, in: tableName) != nil
    }
    
    /// Returns the foreign keys defined on table named `tableName`.
    ///
    /// When `schemaName` is nil, known schemas are iterated in
    /// SQLite resolution order, and the first matching result is returned.
    /// For more information, see <https://www.sqlite.org/lang_naming.html>.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let foreignKeys = try db.foreignKeys(in: "player")
    ///     for foreignKey in foreignKeys {
    ///         print(foreignKey.destinationTable)
    ///     }
    /// }
    /// ```
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, if
    /// the specified schema does not exist, or if no such table or view
    /// with this name exists in the main or temp schema, or in an attached
    /// database.
    public func foreignKeys(on tableName: String, in schemaName: String? = nil) throws -> [ForeignKeyInfo] {
        if let schemaName {
            return try introspect(tableNamed: tableName, inSchemaNamed: schemaName, using: foreignKeys(on:))
        }
        
        for schemaID in try fetchSchemaIdentifiers() {
            if let result = try foreignKeys(on: DatabaseObjectID(name: tableName, schemaID: schemaID)) {
                return result
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    /// Returns nil if table does not exist
    private func foreignKeys(on table: DatabaseObjectID) throws -> [ForeignKeyInfo]? {
        if let foreignKeys = schemaCache[table.schemaID].foreignKeys(on: table.name) {
            return foreignKeys.value
        }
        
        var rawForeignKeys: [(
            id: Int,
            destinationTable: String,
            mapping: [(origin: String, destination: String?, seq: Int)])] = []
        var previousId: Int?
        for row in try Row.fetchAll(self, sql: """
            PRAGMA \(table.schemaID.name).foreign_key_list(\(table.name.quotedDatabaseIdentifier))
            """)
        {
            // row = [id:0 seq:0 table:"parents" from:"parentId" to:"id" on_update:"..." on_delete:"..." match:"..."]
            let id: Int = row[0]
            let seq: Int = row[1]
            let table: String = row[2]
            let origin: String = row[3]
            let destination: String? = row[4]
            
            if previousId == id {
                rawForeignKeys[rawForeignKeys.count - 1]
                    .mapping
                    .append((origin: origin, destination: destination, seq: seq))
            } else {
                let mapping = [(origin: origin, destination: destination, seq: seq)]
                rawForeignKeys.append((id: id, destinationTable: table, mapping: mapping))
                previousId = id
            }
        }
        
        if rawForeignKeys.isEmpty {
            // PRAGMA foreign_key_list doesn't throw any error when table does
            // not exist. So let's check if table exists:
            if try tableExists(table) == false {
                schemaCache[table.schemaID].set(foreignKeys: .missing, forTable: table.name)
                return nil
            }
        }
        
        let foreignKeys = try rawForeignKeys.map { (id, destinationTable, columnMapping) -> ForeignKeyInfo in
            let orderedMapping = columnMapping
                .sorted { $0.seq < $1.seq }
                .map { (origin: $0.origin, destination: $0 .destination) }
            
            let completeMapping: [(origin: String, destination: String)]
            if orderedMapping.contains(where: { (_, destination) in destination == nil }) {
                let pk = try primaryKey(destinationTable)
                completeMapping = zip(pk.columns, orderedMapping).map { (pkColumn, arrow) in
                    (origin: arrow.origin, destination: pkColumn)
                }
            } else {
                completeMapping = orderedMapping.map { (origin, destination) in
                    (origin: origin, destination: destination!)
                }
            }
            return ForeignKeyInfo(id: id, destinationTable: destinationTable, mapping: completeMapping)
        }
        
        schemaCache[table.schemaID].set(foreignKeys: .value(foreignKeys), forTable: table.name)
        return foreignKeys
    }
    
    /// Returns a cursor over foreign key violations in the database.
    public func foreignKeyViolations() throws -> RecordCursor<ForeignKeyViolation> {
        try ForeignKeyViolation.fetchCursor(self, sql: "PRAGMA foreign_key_check")
    }
    
    /// Returns a cursor over foreign key violations in the table.
    ///
    /// When `schemaName` is not specified, known schemas are checked in
    /// SQLite resolution order and the first matching table is used.
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, if
    /// the specified schema does not exist, or if no such table or view
    /// with this name exists in the main or temp schema, or in an attached
    /// database.
    public func foreignKeyViolations(
        in tableName: String,
        in schemaName: String? = nil)
    throws -> RecordCursor<ForeignKeyViolation>
    {
        if let schemaName {
            let schemaID = try schemaIdentifier(named: schemaName)
            if try exists(type: .table, name: tableName, in: schemaID) {
                return try foreignKeyViolations(in: DatabaseObjectID(name: tableName, schemaID: schemaID))
            } else {
                throw DatabaseError.noSuchTable(tableName)
            }
        }
        
        for schemaID in try fetchSchemaIdentifiers() {
            if try exists(type: .table, name: tableName, in: schemaID) {
                return try foreignKeyViolations(in: DatabaseObjectID(name: tableName, schemaID: schemaID))
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    private func foreignKeyViolations(in table: DatabaseObjectID) throws -> RecordCursor<ForeignKeyViolation> {
        try ForeignKeyViolation.fetchCursor(self, sql: """
            PRAGMA \(table.schemaID.name).foreign_key_check(\(table.name.quotedDatabaseIdentifier))
            """)
    }
    
    /// Throws an error if there exists a foreign key violation in the database.
    ///
    /// On the first foreign key violation found in the database, this method
    /// throws a ``DatabaseError`` with extended code
    /// `SQLITE_CONSTRAINT_FOREIGNKEY`.
    ///
    /// If you are looking for the list of foreign key violations, prefer
    /// ``foreignKeyViolations()`` instead.
    public func checkForeignKeys() throws {
        try checkForeignKeys(from: foreignKeyViolations())
    }
    
    /// Throws an error if there exists a foreign key violation in the table.
    ///
    /// When `schemaName` is not specified, known schemas are checked in
    /// SQLite resolution order and the first matching table is used.
    ///
    /// On the first foreign key violation found in the table, this method
    /// throws a ``DatabaseError`` with extended code
    /// `SQLITE_CONSTRAINT_FOREIGNKEY`.
    ///
    /// If you are looking for the list of foreign key violations, prefer
    /// ``foreignKeyViolations(in:in:)`` instead.
    ///
    /// - throws: A ``DatabaseError`` as described above; when a
    /// specified schema does not exist; if no such table or view with this
    /// name exists in the main or temp schema or in an attached database.
    public func checkForeignKeys(in tableName: String, in schemaName: String? = nil) throws {
        try checkForeignKeys(from: foreignKeyViolations(in: tableName, in: schemaName))
    }
    
    private func checkForeignKeys(from violations: RecordCursor<ForeignKeyViolation>) throws {
        if let violation = try violations.next() {
            throw violation.databaseError(self)
        }
    }
    
    /// Returns the actual name of the database table, or nil if the table does
    /// not exist.
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or if no
    /// such table exists in the main or temp schema, or in an
    /// attached database.
    func canonicalTableName(_ tableName: String) throws -> String? {
        for schemaID in try fetchSchemaIdentifiers() {
            // Regular tables
            if let result = try schema(schemaID).canonicalName(tableName, ofType: .table) {
                return result
            }
            
            // Master table (sqlite_master, sqlite_temp_master)
            let schemaTableName = schemaID.unqualifiedSchemaTableName
            if tableName.lowercased() == schemaTableName.lowercased() {
                return schemaTableName
            }
        }
        return nil
    }
    
    func schema(_ schemaID: DatabaseSchemaID) throws -> SchemaInfo {
        if let schemaInfo = schemaCache[schemaID].schemaInfo {
            return schemaInfo
        }
        let schemaInfo = try SchemaInfo(self, schemaTableName: schemaID.schemaTableName)
        schemaCache[schemaID].schemaInfo = schemaInfo
        return schemaInfo
    }
    
    /// Attempts to perform a table introspection function on a given
    /// table and schema.
    ///
    /// - parameter tableName: The name of the table to examine
    /// - parameter schemaName: The name of the schema to check
    /// - parameter introspector: An introspection function taking a
    ///     `DatabaseObjectID` as the only parameter. It the result
    ///     is nil, introspection fails and this method throws
    ///     `DatabaseError.noSuchTable`.
    private func introspect<T>(
        tableNamed tableName: String,
        inSchemaNamed schemaName: String,
        using introspector: (DatabaseObjectID) throws -> T?
    ) throws -> T {
        let schemaID = try schemaIdentifier(named: schemaName)
        let table = DatabaseObjectID(name: tableName, schemaID: schemaID)
        
        if let result = try introspector(table) {
            return result
        } else {
            throw DatabaseError.noSuchTable(tableName)
        }
    }
}

extension Database {
    
    /// Returns the columns in a table or a view.
    ///
    /// When `schemaName` is nil, known schemas are iterated in
    /// SQLite resolution order, and the first matching result is returned.
    /// For more information, see <https://www.sqlite.org/lang_naming.html>.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let columns = try db.columns(in: "player")
    ///     for column in columns {
    ///         print(column.name)
    ///     }
    /// }
    /// ```
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, if
    /// the specified schema does not exist,or if no such table or view
    /// with this name exists in the main or temp schema, or in an attached
    /// database.
    public func columns(in tableName: String, in schemaName: String? = nil) throws -> [ColumnInfo] {
        if let schemaName {
            return try introspect(tableNamed: tableName, inSchemaNamed: schemaName, using: columns(in:))
        }
        
        for schemaID in try fetchSchemaIdentifiers() {
            if let result = try columns(in: DatabaseObjectID(name: tableName, schemaID: schemaID)) {
                return result
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    /// Returns nil if table does not exist.
    private func columns(in table: DatabaseObjectID) throws -> [ColumnInfo]? {
        if let columns = schemaCache[table.schemaID].columns(in: table.name) {
            return columns.value
        }
        
        if var columns = try fetchPrimitiveColumns(in: table) {
            // Discard hidden columns, so that the result of this method
            // matches the columns in `SELECT *`, and avoids surprises.
            columns = columns.filter {
                // https://www.sqlite.org/pragma.html#pragma_table_xinfo
                $0.hidden != 1
            }
            schemaCache[table.schemaID].set(columns: .value(columns), forTable: table.name)
            return columns
        } else {
            // Table does not exist
            schemaCache[table.schemaID].set(columns: .missing, forTable: table.name)
            return nil
        }
    }
    
    /// Fetches the columns in the database table identified by `table`, or
    /// returns nil if the database schema does not contain that table.
    ///
    /// This method relies entirely on SQLite schema introspection. Starting
    /// SQLite 3.26.0, it returns all columns, including
    /// [generated columns](https://www.sqlite.org/gencol.html) and
    /// [hidden columns](https://www.sqlite.org/vtab.html#hiddencol).
    func fetchPrimitiveColumns(in table: DatabaseObjectID) throws -> [ColumnInfo]? {
        // https://www.sqlite.org/pragma.html
        //
        // > PRAGMA database.table_info(table-name);
        // >
        // > This pragma returns one row for each column in the named table.
        // > Columns in the result set include the column name, data type,
        // > whether or not the column can be NULL, and the default value for
        // > the column. The "pk" column in the result set is zero for columns
        // > that are not part of the primary key, and is the index of the
        // > column in the primary key for columns that are part of the primary
        // > key.
        //
        // sqlite> CREATE TABLE players (
        //   id INTEGER PRIMARY KEY,
        //   firstName TEXT,
        //   lastName TEXT);
        //
        // sqlite> PRAGMA table_info("players");
        // cid | name  | type    | notnull | dflt_value | pk |
        // 0   | id    | INTEGER | 0       | NULL       | 1  |
        // 1   | name  | TEXT    | 0       | NULL       | 0  |
        // 2   | score | INTEGER | 0       | NULL       | 0  |
        //
        //
        // PRAGMA table_info does not expose hidden and generated columns. For
        // that, we need PRAGMA table_xinfo, introduced in SQLite 3.26.0:
        // https://sqlite.org/releaselog/3_26_0.html
        //
        // > PRAGMA schema.table_xinfo(table-name);
        //
        // > This pragma returns one row for each column in the named table,
        // > including hidden columns in virtual tables. The output is the same
        // > as for PRAGMA table_info except that hidden columns are shown
        // > rather than being omitted.
        //
        // sqlite> PRAGMA table_xinfo("players");
        // cid | name      | type    | notnull | dflt_value | pk | hidden
        // 0   | id        | INTEGER | 0       | NULL       | 1  | 0
        // 1   | firstName | TEXT    | 0       | NULL       | 0  | 0
        // 2   | lastName  | TEXT    | 0       | NULL       | 0  | 0
        let columnInfoQuery: String
        if sqlite3_libversion_number() < 3026000 {
            columnInfoQuery = "PRAGMA \(table.schemaID.name).table_info(\(table.name.quotedDatabaseIdentifier))"
        } else {
            // Use PRAGMA table_xinfo so that we can load generated columns
            columnInfoQuery = "PRAGMA \(table.schemaID.name).table_xinfo(\(table.name.quotedDatabaseIdentifier))"
        }
        let columns = try ColumnInfo
            .fetchAll(self, sql: columnInfoQuery)
            .sorted(by: { $0.cid < $1.cid })
        
        if columns.isEmpty {
            // Table does not exist
            return nil
        }
        
        return columns
    }
    
    /// If there exists a unique key that contains those columns, this method
    /// returns the columns of the unique key, ordered as the matching index (or
    /// primary key). The case of returned columns is not guaranteed to match
    /// the case of input columns.
    ///
    /// This method accepts both tables and views. For views, the primary
    /// key returned by the schemaSource is considered as a unique key.
    func columnsForUniqueKey(
        _ columns: some Collection<String>,
        in tableName: String
    ) throws -> [String]? {
        let lowercasedColumns = Set(columns.map { $0.lowercased() })
        if lowercasedColumns.isEmpty {
            // Don't hit the database for trivial case
            return nil
        }
        
        // Check primaryKey (ignoring views if the schemaSource does not customize them).
        if let primaryKey = try? self.primaryKey(tableName) {
            if primaryKey.tableHasRowID && lowercasedColumns == ["rowid"] {
                return ["rowid"]
            }
            
            // Check primaryKey
            if Set(primaryKey.columns.map { $0.lowercased() }).isSubset(of: lowercasedColumns) {
                return primaryKey.columns
            }
        }
        
        // Check unique indexes (ignoring views)
        if try tableExists(tableName) {
            let matchingIndex = try indexes(on: tableName).first { index in
                index.isUnique && Set(index.columns.map { $0.lowercased() }).isSubset(of: lowercasedColumns)
            }
            if let matchingIndex {
                return matchingIndex.columns
            }
        }
        
        // No matching unique key found
        return nil
    }
    
    /// Returns the columns to check for NULL in order to check if the row exist.
    ///
    /// The returned array is never empty.
    func existenceCheckColumns(in tableName: String) throws -> [String] {
        do {
            // Check the primary key columns for existence
            let primaryKey = try self.primaryKey(tableName)
            if let rowIDColumn = primaryKey.rowIDColumn {
                // Prefer the user-provided name of the rowid
                //
                //  // CREATE TABLE player (id INTEGER PRIMARY KEY, ...)
                //  try db.existenceCheckColumns(in: "player") // ["id"]
                return [rowIDColumn]
            } else if primaryKey.tableHasRowID {
                // Prefer the rowid
                //
                //  // CREATE TABLE player (uuid TEXT NOT NULL PRIMARY KEY, ...)
                //  try db.existenceCheckColumns(in: "player") // ["rowid"]
                return [Column.rowID.name]
            } else {
                // WITHOUT ROWID table: use primary key columns
                //
                //  // CREATE TABLE player (uuid TEXT NOT NULL PRIMARY KEY, ...) WITHOUT ROWID
                //  try db.existenceCheckColumns(in: "player") // ["uuid"]
                return primaryKey.columns
            }
        } catch let error as DatabaseError {
            if case .SQLITE_ERROR = error.resultCode,
               (try? viewExists(tableName)) == true
            {
                // View without primary key: check all columns for existence
                return try columns(in: tableName).map(\.name)
            } else {
                throw error
            }
        }
    }
}

/// The identifier of an SQLite schema.
///
/// For more information, see <https://sqlite.org/lang_naming.html>
public struct DatabaseSchemaID: Hashable, Sendable {
    private enum Impl: Hashable {
        /// The main database
        case main
        
        /// The temp database
        case temp
        
        /// An attached database: <https://sqlite.org/lang_attach.html>
        case attached(String)
    }
    
    private var impl: Impl
    
    private init(impl: Impl) {
        self.impl = impl
    }
    
    init(name: String) {
        switch name {
        case "main": self = .main
        case "temp": self = .temp
        case let other: self = .attached(other)
        }
    }
    
    /// The identifier of the "main" database schema.
    public static let main = DatabaseSchemaID(impl: .main)
    
    /// The identifier of the "temp" database schema.
    public static let temp = DatabaseSchemaID(impl: .temp)
    
    /// The identifier of an attached database schema.
    public static func attached(_ name: String) -> DatabaseSchemaID {
        DatabaseSchemaID(impl: .attached(name))
    }
    
    /// The name of the schema, suitable for inclusion in SQL queries.
    ///
    /// For example:
    ///
    ///     SELECT * FROM main.player;
    ///                   ~~~~
    public var name: String {
        switch impl {
        case .main: return "main"
        case .temp: return "temp"
        case let .attached(name): return name
        }
    }
    
    /// The name of the schema sqlite table.
    ///
    /// For more information, see <https://sqlite.org/schematab.html>
    public var schemaTableName: String {
        switch impl {
        case .main: return "sqlite_master"
        case .temp: return "sqlite_temp_master"
        case let .attached(name): return "\(name).sqlite_master"
        }
    }
    
    /// The name of the schema sqlite table, without the schema name.
    var unqualifiedSchemaTableName: String {
        switch impl {
        case .main, .attached: return "sqlite_master"
        case .temp: return "sqlite_temp_master"
        }
    }
    
    func viewNameInErrorMessages(_ viewName: String) -> String {
        switch impl {
        case .main:
            return "view \(viewName)"
        case .temp:
            return "temporary view \(viewName)"
        case .attached(let schemaName):
            return "view \(schemaName).\(viewName)"
        }
    }
}

/// The identifier of an object in the database (table, view, etc.)
public struct DatabaseObjectID: Hashable, Sendable {
    /// The object name.
    public var name: String
    
    /// The SQLite schema.
    public var schemaID: DatabaseSchemaID
    
    public init(name: String, schemaID: DatabaseSchemaID) {
        self.name = name
        self.schemaID = schemaID
    }
    
    /// Returns a quoted version of the identifier, for safe insertion in
    /// an SQL query.
    ///
    /// For example:
    ///
    /// ```
    /// let object = DatabaseObjectID(name: "player", schemaID: .temp)
    ///
    /// // SELECT * FROM temp.player
    /// db.execute(sql: "SELECT * FROM \(object.quotedDatabaseIdentifier)")
    /// ```
    var quotedDatabaseIdentifier: String {
        "\(schemaID.name).\(name.quotedDatabaseIdentifier)"
    }
}

/// Information about a column of a database table.
///
/// You get `ColumnInfo` instances with the ``Database/columns(in:in:)``
/// `Database` method.
///
/// Related SQLite documentation:
///
/// - [pragma `table_info`](https://www.sqlite.org/pragma.html#pragma_table_info)
/// - [pragma `table_xinfo`](https://www.sqlite.org/pragma.html#pragma_table_xinfo)
public struct ColumnInfo: FetchableRecord, Sendable {
    let cid: Int
    let hidden: Int?
    
    /// The column name.
    public let name: String
    
    /// The column data type.
    ///
    /// The casing of this string depends on the SQLite version: make sure you
    /// process this string in a case-insensitive way.
    ///
    /// The type is the empty string when the column has no declared type.
    public let type: String
    
    /// The column data type (nil when the column has no declared type).
    ///
    /// The casing of the raw value depends on the SQLite version: make sure
    /// you process the result in a case-insensitive way.
    var columnType: Database.ColumnType? {
        if type.isEmpty {
            return nil
        } else {
            return Database.ColumnType(rawValue: type)
        }
    }
    
    /// A boolean value indicating if the column is constrained to be not null.
    public let isNotNull: Bool
    
    /// The SQL snippet that defines the default value, if any.
    ///
    /// When nil, the column has no default value.
    ///
    /// When not nil, it contains an SQL string that defines an expression. That
    /// expression may be a literal, as `1`, or `'foo'`. It may also contain a
    /// non-constant expression such as `CURRENT_TIMESTAMP`.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#the_default_clause>.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.execute(sql: """
    ///     CREATE TABLE player(
    ///         id INTEGER PRIMARY KEY,
    ///         name TEXT DEFAULT 'Anonymous',
    ///         score INT DEFAULT 0,
    ///         creationDate DATE DEFAULT CURRENT_TIMESTAMP
    ///     )
    ///     """)
    /// let columnInfos = try db.columns(in: "player")
    /// columnInfos[0].defaultValueSQL // nil
    /// columnInfos[1].defaultValueSQL // "'Anonymous'"
    /// columnInfos[2].defaultValueSQL // "0"
    /// columnInfos[3].defaultValueSQL // "CURRENT_TIMESTAMP"
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html#the_default_clause>.
    public let defaultValueSQL: String?
    
    /// The one-based index of the column in the primary key.
    ///
    /// For columns that are not part of the primary key, it is zero.
    public fileprivate(set) var primaryKeyIndex: Int
    
    public init(row: Row) {
        cid = row["cid"]
        name = row["name"]
        type = row["type"]
        isNotNull = row["notnull"]
        defaultValueSQL = row["dflt_value"]
        primaryKeyIndex = row["pk"]
        hidden = row["hidden"]
    }
}

/// Information about an index.
///
/// You get `IndexInfo` instances with the ``Database/indexes(on:in:)``
/// `Database` method.
///
/// Related SQLite documentation:
///
/// - [pragma `index_list`](https://www.sqlite.org/pragma.html#pragma_index_list)
/// - [pragma `index_info`](https://www.sqlite.org/pragma.html#pragma_index_info)
public struct IndexInfo: Sendable{
    /// The origin of an index.
    public struct Origin: RawRepresentable, Equatable, DatabaseValueConvertible, Sendable {
        public var rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// An index created from a `CREATE INDEX` statement.
        public static let createIndex = Origin(rawValue: "c")
        
        /// An index created by a `UNIQUE` constraint.
        public static let uniqueConstraint = Origin(rawValue: "u")
        
        /// An index created by a `PRIMARY KEY` constraint.
        public static let primaryKeyConstraint = Origin(rawValue: "pk")
    }
    
    /// The name of the index.
    public let name: String
    
    /// The indexed columns.
    public let columns: [String]
    
    /// A boolean value indicating if the index is unique.
    public let isUnique: Bool
    
    /// The origin of the index.
    public let origin: Origin
}

/// A foreign key violation.
///
/// You get instances of `ForeignKeyViolation` from the `Database` methods
/// ``Database/foreignKeyViolations()`` and
/// ``Database/foreignKeyViolations(in:in:)`` methods.
///
/// For example:
///
/// ```swift
/// try dbQueue.read {
///     let violations = try db.foreignKeyViolations()
///     while let violation = try violations.next() {
///         // The name of the table that contains the `REFERENCES` clause
///         violation.originTable
///
///         // The rowid of the row that contains the invalid `REFERENCES` clause, or
///         // nil if the origin table is a `WITHOUT ROWID` table.
///         violation.originRowID
///
///         // The name of the table that is referred to.
///         violation.destinationTable
///
///         // The id of the specific foreign key constraint that failed. This id
///         // matches `ForeignKeyInfo.id`. See `Database.foreignKeys(on:)` for more
///         // information.
///         violation.foreignKeyId
///
///         // Plain description:
///         // "FOREIGN KEY constraint violation - from player to team, in rowid 1"
///         String(describing: violation)
///
///         // Rich description:
///         // "FOREIGN KEY constraint violation - from player(teamId) to team(id),
///         //  in [id:1 teamId:2 name:"O'Brien" score:1000]"
///         try violation.failureDescription(db)
///
///         // Turn violation into a DatabaseError
///         throw violation.databaseError(db)
///     }
/// }
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/pragma.html#pragma_foreign_key_check>
public struct ForeignKeyViolation: Sendable {
    /// The name of the table that contains the foreign key.
    public var originTable: String
    
    /// The rowid of the row that contains the foreign key violation.
    ///
    /// If it nil if the origin table is a `WITHOUT ROWID` table.
    public var originRowID: Int64?
    
    /// The name of the table that is referred to.
    public var destinationTable: String
    
    /// The id of the foreign key constraint that failed.
    ///
    /// This id matches the ``ForeignKeyInfo/id`` property in
    /// ``ForeignKeyInfo``. See ``Database/foreignKeys(on:in:)``.
    public var foreignKeyId: Int
    
    /// A precise description of the foreign key violation.
    ///
    /// For example:
    ///
    /// ```
    /// FOREIGN KEY constraint violation - from player(teamId) to team(id),
    /// in [id:1 teamId:2 name:"O'Brien" score: 1000]
    /// ```
    ///
    /// See also ``description``.
    public func failureDescription(_ db: Database) throws -> String {
        // Grab detailed information, if possible, for better error message
        let originRow = try originRowID.flatMap { rowid in
            try Row.fetchOne(db, sql: "SELECT * FROM \(originTable.quotedDatabaseIdentifier) WHERE rowid = \(rowid)")
        }
        let foreignKey = try db.foreignKeys(on: originTable).first(where: { foreignKey in
            foreignKey.id == foreignKeyId
        })
        
        var description: String
        if let foreignKey {
            description = """
                FOREIGN KEY constraint violation - \
                from \(originTable)(\(foreignKey.originColumns.joined(separator: ", "))) \
                to \(destinationTable)(\(foreignKey.destinationColumns.joined(separator: ", ")))
                """
        } else {
            description = "FOREIGN KEY constraint violation - from \(originTable) to \(destinationTable)"
        }
        
        if let originRow {
            description += ", in \(String(describing: originRow))"
        } else if let originRowID {
            description += ", in rowid \(originRowID)"
        }
        
        return description
    }
    
    /// Converts the violation into a ``DatabaseError``.
    ///
    /// The returned error has the extended code `SQLITE_CONSTRAINT_FOREIGNKEY`.
    public func databaseError(_ db: Database) -> DatabaseError {
        // Grab detailed information, if possible, for better error message.
        // If detailed information is not available, fallback to plain description.
        let message = (try? failureDescription(db)) ?? String(describing: self)
        return DatabaseError(
            resultCode: .SQLITE_CONSTRAINT_FOREIGNKEY,
            message: message)
    }
}

extension ForeignKeyViolation: FetchableRecord {
    public init(row: Row) {
        originTable = row[0]
        originRowID = row[1]
        destinationTable = row[2]
        foreignKeyId = row[3]
    }
}

extension ForeignKeyViolation: CustomStringConvertible {
    /// A description of the foreign key violation.
    ///
    /// For example:
    ///
    /// ```
    /// FOREIGN KEY constraint violation - from player to team, in rowid 1
    /// ```
    ///
    /// See also ``failureDescription(_:)``.
    public var description: String {
        if let originRowID {
            return """
                FOREIGN KEY constraint violation - from \(originTable) to \(destinationTable), \
                in rowid \(originRowID)
                """
        } else {
            return """
                FOREIGN KEY constraint violation - from \(originTable) to \(destinationTable)
                """
        }
    }
}

/// Information about a primary key.
///
/// You get `PrimaryKeyInfo` instances with the ``Database/primaryKey(_:in:)``
/// `Database` method.
///
/// When the table's primary key is the rowid:
///
/// ```swift
/// // CREATE TABLE item (name TEXT)
/// let pk = try db.primaryKey("item")
/// pk.columns     // ["rowid"]
/// pk.rowIDColumn // nil
/// pk.isRowID     // true
///
/// // CREATE TABLE citizen (
/// //   id INTEGER PRIMARY KEY,
/// //   name TEXT
/// // )
/// let pk = try db.primaryKey("citizen")!
/// pk.columns     // ["id"]
/// pk.rowIDColumn // "id"
/// pk.isRowID     // true
/// ```
///
/// When the table's primary key is not the rowid:
///
/// ```swift
/// // CREATE TABLE country (
/// //   isoCode TEXT NOT NULL PRIMARY KEY
/// //   name TEXT
/// // )
/// let pk = try db.primaryKey("country")!
/// pk.columns     // ["isoCode"]
/// pk.rowIDColumn // nil
/// pk.isRowID     // false
///
/// // CREATE TABLE citizenship (
/// //   citizenID INTEGER NOT NULL REFERENCES citizen(id)
/// //   countryIsoCode TEXT NOT NULL REFERENCES country(isoCode)
/// //   PRIMARY KEY (citizenID, countryIsoCode)
/// // )
/// let pk = try db.primaryKey("citizenship")!
/// pk.columns     // ["citizenID", "countryIsoCode"]
/// pk.rowIDColumn // nil
/// pk.isRowID     // false
/// ```
public struct PrimaryKeyInfo: Sendable {
    private enum Impl {
        /// The hidden rowID.
        case hiddenRowID
        
        /// An INTEGER PRIMARY KEY column that aliases the Row ID.
        /// Associated string is the column name.
        case rowID(ColumnInfo)
        
        /// Any primary key, but INTEGER PRIMARY KEY.
        /// Associated strings are column names.
        case regular(columnInfos: [ColumnInfo], tableHasRowID: Bool)
    }
    
    private let impl: Impl
    
    static func rowID(_ columnInfo: ColumnInfo) -> PrimaryKeyInfo {
        PrimaryKeyInfo(impl: .rowID(columnInfo))
    }
    
    static func regular(_ columnInfos: [ColumnInfo], tableHasRowID: Bool) -> PrimaryKeyInfo {
        assert(!columnInfos.isEmpty)
        return PrimaryKeyInfo(impl: .regular(columnInfos: columnInfos, tableHasRowID: tableHasRowID))
    }
    
    static let hiddenRowID = PrimaryKeyInfo(impl: .hiddenRowID)
    
    /// The columns in the primary key. This array is never empty.
    public var columns: [String] {
        switch impl {
        case .hiddenRowID:
            return [Column.rowID.name]
        case let .rowID(columnInfo):
            return [columnInfo.name]
        case let .regular(columnInfos: columnInfos, tableHasRowID: _):
            return columnInfos.map(\.name)
        }
    }
    
    /// The columns in the primary key. Nil if the primary key is the
    /// hidden rowID. Never empty otherwise.
    var columnInfos: [ColumnInfo]? {
        switch impl {
        case .hiddenRowID:
            return nil
        case let .rowID(columnInfo):
            return [columnInfo]
        case let .regular(columnInfos: columnInfos, tableHasRowID: _):
            return columnInfos
        }
    }
    
    /// When not nil, the name of the column that contains the
    /// `INTEGER PRIMARY KEY`.
    public var rowIDColumn: String? {
        switch impl {
        case .hiddenRowID:
            return nil
        case .rowID(let columnInfo):
            return columnInfo.name
        case .regular:
            return nil
        }
    }
    
    /// A boolean value indicating if the primary key is the rowid.
    public var isRowID: Bool {
        switch impl {
        case .hiddenRowID:
            return true
        case .rowID:
            return true
        case .regular:
            return false
        }
    }
    
    /// A boolean value indicating if the table has a rowid.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/withoutrowid.html>
    var tableHasRowID: Bool {
        switch impl {
        case .hiddenRowID:
            return true
        case .rowID:
            return true
        case let .regular(columnInfos: _, tableHasRowID: tableHasRowID):
            return tableHasRowID
        }
    }
    
    /// The name of the fastest primary key column.
    ///
    /// Returns nil for WITHOUT ROWID tables with a multi-columns primary key
    var fastPrimaryKeyColumn: String? {
        if let rowIDColumn {
            // Prefer the user-provided name of the rowid
            //
            //  // CREATE TABLE player (id INTEGER PRIMARY KEY, ...)
            //  try db.primaryKey("player").fastPrimaryKeyColumn // "id"
            return rowIDColumn
        } else if tableHasRowID {
            // Prefer the rowid
            //
            //  // CREATE TABLE player (uuid TEXT NOT NULL PRIMARY KEY, ...)
            //  try db.primaryKey("player").fastPrimaryKeyColumn // "rowid"
            return Column.rowID.name
        } else if columns.count == 1 {
            // WITHOUT ROWID table or view customized with the schemaSource:
            // use primary key column
            //
            //  // CREATE TABLE player (uuid TEXT NOT NULL PRIMARY KEY, ...) WITHOUT ROWID
            //  try db.primaryKey("player").fastPrimaryKeyColumn // "uuid"
            return columns[0]
        } else {
            // WITHOUT ROWID table or view customized with the schemaSource
            // with a multi-columns primary key
            return nil
        }
    }
}

/// Information about a foreign key.
///
/// You get `ForeignKeyInfo` instances with the ``Database/foreignKeys(on:in:)``
/// `Database` method.
///
/// Related SQLite documentation: [pragma `foreign_key_list`](https://www.sqlite.org/pragma.html#pragma_foreign_key_list).
public struct ForeignKeyInfo: Sendable {
    /// The first column in the output of the `foreign_key_list` pragma.
    public var id: Int
    
    /// The name of the destination table.
    public let destinationTable: String
    
    /// The column to column mapping.
    public let mapping: [(origin: String, destination: String)]
    
    /// The origin columns.
    public var originColumns: [String] {
        mapping.map(\.origin)
    }
    
    /// The destination columns.
    public var destinationColumns: [String] {
        mapping.map(\.destination)
    }
}

/// Related SQLite documentation: <https://www.sqlite.org/pragma.html#pragma_table_list>
struct TableInfo: FetchableRecord {
    struct Kind: RawRepresentable {
        var rawValue: String
        
        static let table = Kind(rawValue: "table")
        static let view = Kind(rawValue: "view")
        static let shadow = Kind(rawValue: "shadow")
        static let virtual = Kind(rawValue: "virtual")
    }
    
    var schemaID: DatabaseSchemaID
    var name: String
    var kind: Kind
    var columnCount: Int
    /// False for tables with a rowid, and for views.
    var isWithoutRowIDTable: Bool
    var strict: Bool
    
    init(row: Row) throws {
        schemaID = DatabaseSchemaID(name: row[0] as String)
        name = row[1]
        kind = Kind(rawValue: row[2])
        columnCount = row[3]
        isWithoutRowIDTable = row[4]
        strict = row[5]
    }
}

/// A value in the `type` column of `sqlite_master`.
struct SchemaObjectType: Hashable, RawRepresentable, DatabaseValueConvertible {
    var rawValue: String
    static let index = SchemaObjectType(rawValue: "index")
    static let table = SchemaObjectType(rawValue: "table")
    static let trigger = SchemaObjectType(rawValue: "trigger")
    static let view = SchemaObjectType(rawValue: "view")
}

/// A row in `sqlite_master`.
struct SchemaObject: Hashable, FetchableRecord {
    var type: SchemaObjectType
    var name: String
    var tbl_name: String?
    var sql: String?
    
    init(row: Row) throws {
        // "rootpage" column is not always there: avoid using numerical indexes
        type = row["type"]
        name = row["name"]
        tbl_name = row["tbl_name"]
        sql = row["sql"]
    }
}

/// All objects in a database schema (tables, views, indexes, triggers).
struct SchemaInfo: Equatable {
    let objects: Set<SchemaObject>
    
    /// Returns whether there exists a object of given type with this name
    /// (case-insensitive).
    func containsObjectNamed(_ name: String, ofType type: SchemaObjectType) -> Bool {
        let name = name.lowercased()
        return objects.contains {
            $0.type == type && $0.name.lowercased() == name
        }
    }
    
    /// Returns the canonical name of the object:
    ///
    ///     try db.execute(sql: "CREATE TABLE FooBar (...)")
    ///     try db.schema().canonicalName("foobar", ofType: .table) // "FooBar"
    func canonicalName(_ name: String, ofType type: SchemaObjectType) -> String? {
        let name = name.lowercased()
        return objects
            .first { $0.type == type && $0.name.lowercased() == name }?
            .name
    }
    
    func filter(_ isIncluded: (SchemaObject) -> Bool) -> Self {
        SchemaInfo(objects: objects.filter(isIncluded))
    }
}

extension SchemaInfo {
    /// - parameter schemaTableName: "sqlite_master" or "sqlite_temp_master"
    init(_ db: Database, schemaTableName: String) throws {
        objects = try SchemaObject.fetchSet(db, sql: """
            SELECT type, name, tbl_name, sql FROM \(schemaTableName)
            """)
    }
}
