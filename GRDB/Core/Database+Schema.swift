extension Database {
    /// A SQLite schema. See <https://sqlite.org/lang_naming.html>
    enum SchemaIdentifier: Hashable {
        /// The main database
        case main
        
        /// The temp database
        case temp
        
        /// An attached database: <https://sqlite.org/lang_attach.html>
        case attached(String)
        
        /// The name of the schema in SQL queries
        var sql: String {
            switch self {
            case .main: return "main"
            case .temp: return "temp"
            case let .attached(name): return name
            }
        }
        
        /// The name of the master sqlite table
        var masterTableName: String { // swiftlint:disable:this inclusive_language
            switch self {
            case .main: return "sqlite_master"
            case .temp: return "sqlite_temp_master"
            case let .attached(name): return "\(name).sqlite_master"
            }
        }
    }
    
    /// A table identifier
    struct TableIdentifier {
        /// The SQLite schema
        var schemaID: SchemaIdentifier
        
        /// The table name
        var name: String
        
        /// Returns the receiver, quoted for safe insertion as an identifier in
        /// an SQL query.
        ///
        ///     // SELECT * FROM temp.player
        ///     db.execute(sql: "SELECT * FROM \(table.quotedDatabaseIdentifier)")
        var quotedDatabaseIdentifier: String {
            "\(schemaID.sql).\(name.quotedDatabaseIdentifier)"
        }
    }
    
    // MARK: - Database Schema
    
    /// Clears the database schema cache.
    ///
    /// You may need to clear the cache manually if the database schema is
    /// modified by another connection.
    public func clearSchemaCache() {
        SchedulingWatchdog.preconditionValidQueue(self)
        schemaCache.clear()
        
        // We also clear statement cache despite the automatic statement
        // recompilation (see https://www.sqlite.org/c3ref/prepare.html)
        // because the automatic statement recompilation only happens a
        // limited number of times.
        internalStatementCache.clear()
        publicStatementCache.clear()
    }
    
    /// Clears the database schema cache if the database schema has changed
    /// since this method was last called.
    func clearSchemaCacheIfNeeded() throws {
        let schemaVersion = try Int32.fetchOne(internalCachedStatement(sql: "PRAGMA schema_version"))
        if _lastSchemaVersion != schemaVersion {
            _lastSchemaVersion = schemaVersion
            clearSchemaCache()
        }
    }
    
    /// The list of database schemas, in the order of SQLite resolution:
    /// temp, main, then attached databases.
    func schemaIdentifiers() throws -> [SchemaIdentifier] {
        if let schemaIdentifiers = schemaCache.schemaIdentifiers {
            return schemaIdentifiers
        }
        
        var schemaIdentifiers = try Row
            .fetchAll(self, sql: "PRAGMA database_list")
            .map { row -> SchemaIdentifier in
                switch row[1] as String {
                case "main": return .main
                case "temp": return .temp
                case let other: return .attached(other)
                }
            }
        
        // Temp schema shadows other schema: put it first
        if let tempIdx = schemaIdentifiers.firstIndex(of: .temp) {
            schemaIdentifiers.swapAt(tempIdx, 0)
        }
        
        schemaCache.schemaIdentifiers = schemaIdentifiers
        return schemaIdentifiers
    }
    
    /// Returns whether a table exists in the main or temp schema.
    public func tableExists(_ name: String) throws -> Bool {
        try schemaIdentifiers().contains {
            try exists(type: .table, name: name, in: $0)
        }
    }
    
    private func tableExists(_ table: TableIdentifier) throws -> Bool {
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
    
    /// Returns whether a table is an internal SQLite table.
    ///
    /// Those are tables whose name begins with `sqlite_` and `pragma_`.
    ///
    /// For more information, see <https://www.sqlite.org/fileformat2.html>
    @available(*, deprecated, message: "Use Database.isSQLiteInternalTable(_:) static method instead.")
    public func isSQLiteInternalTable(_ tableName: String) -> Bool {
        Self.isSQLiteInternalTable(tableName)
    }
    
    /// Returns whether a table is an internal GRDB table.
    ///
    /// Those are tables whose name begins with "grdb_".
    public static func isGRDBInternalTable(_ tableName: String) -> Bool {
        tableName.starts(with: "grdb_")
    }
    
    /// Returns whether a table is an internal GRDB table.
    ///
    /// Those are tables whose name begins with "grdb_".
    @available(*, deprecated, message: "Use Database.isGRDBInternalTable(_:) static method instead.")
    public func isGRDBInternalTable(_ tableName: String) -> Bool {
        Self.isGRDBInternalTable(tableName)
    }
    
    /// Returns whether a view exists in the main or temp schema.
    public func viewExists(_ name: String) throws -> Bool {
        try schemaIdentifiers().contains {
            try exists(type: .view, name: name, in: $0)
        }
    }
    
    /// Returns whether a trigger exists in the main or temp schema.
    public func triggerExists(_ name: String) throws -> Bool {
        try schemaIdentifiers().contains {
            try exists(type: .trigger, name: name, in: $0)
        }
    }
    
    private func exists(type: SchemaObjectType, name: String, in schemaID: SchemaIdentifier) throws -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving:
        // http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html
        let name = name.lowercased()
        return try schema(schemaID)
            .names(ofType: type)
            .contains { $0.lowercased() == name }
    }
    
    /// The primary key for table named `tableName`.
    ///
    /// All tables have a primary key, even when it is not explicit. When a
    /// table has no explicit primary key, the result is the hidden
    /// "rowid" column.
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func primaryKey(_ tableName: String) throws -> PrimaryKeyInfo {
        for schemaIdentifier in try schemaIdentifiers() {
            if let result = try primaryKey(TableIdentifier(schemaID: schemaIdentifier, name: tableName)) {
                return result
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    /// Returns nil if table does not exist
    private func primaryKey(_ table: TableIdentifier) throws -> PrimaryKeyInfo? {
        SchedulingWatchdog.preconditionValidQueue(self)
        
        if let primaryKey = schemaCache[table.schemaID].primaryKey(table.name) {
            return primaryKey.value
        }
        
        if try !tableExists(table) {
            // Views, CTEs, etc.
            schemaCache[table.schemaID].set(primaryKey: .missing, forTable: table.name)
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
            schemaCache[table.schemaID].set(primaryKey: .missing, forTable: table.name)
            return nil
        }
        
        let primaryKey: PrimaryKeyInfo
        let pkColumns = columns
            .filter { $0.primaryKeyIndex > 0 }
            .sorted { $0.primaryKeyIndex < $1.primaryKeyIndex }
        
        switch pkColumns.count {
        case 0:
            // No explicit primary key => primary key is hidden rowID column
            primaryKey = .hiddenRowID
        case 1:
            // Single column
            let pkColumn = pkColumns.first!
            
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
                primaryKey = .rowID(pkColumn.name)
            } else {
                primaryKey = try .regular([pkColumn.name], tableHasRowID: tableHasRowID(table))
            }
        default:
            // Multi-columns primary key
            primaryKey = try .regular(pkColumns.map(\.name), tableHasRowID: tableHasRowID(table))
        }
        
        schemaCache[table.schemaID].set(primaryKey: .value(primaryKey), forTable: table.name)
        return primaryKey
    }
    
    /// Returns whether the column identifies the rowid column
    func columnIsRowID(_ column: String, of tableName: String) throws -> Bool {
        let pk = try primaryKey(tableName)
        return pk.rowIDColumn == column || (pk.tableHasRowID && column.uppercased() == "ROWID")
    }
    
    /// Returns whether the table has a rowid column.
    ///
    /// - precondition: table exists.
    private func tableHasRowID(_ table: TableIdentifier) throws -> Bool {
        // Not need to cache the result, because this information feeds
        // `PrimaryKeyInfo`, which is cached.
        //
        // Use a distinctive alias so that we better understand in the
        // future why this query appears in the error log.
        // https://github.com/groue/GRDB.swift/issues/945#issuecomment-804896196
        //
        // We don't use `try makeStatement(sql:)` in order to avoid throwing an
        // error (this annoys users who set a breakpoint on Swift errors).
        let sql = "SELECT rowid AS checkWithoutRowidOptimization FROM \(table.quotedDatabaseIdentifier)"
        var statement: SQLiteStatement? = nil
        let code = sqlite3_prepare_v2(sqliteConnection, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        return code == SQLITE_OK
    }
    
    /// The indexes on table named `tableName`.
    ///
    /// Only indexes on columns are returned. Indexes on expressions are
    /// not returned.
    ///
    /// SQLite does not define any index for INTEGER PRIMARY KEY columns: this
    /// method does not return any index that represents the primary key.
    ///
    /// If you want to know if a set of columns uniquely identify a row, prefer
    /// `table(_:hasUniqueKey:)` instead.
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func indexes(on tableName: String) throws -> [IndexInfo] {
        for schemaIdentifier in try schemaIdentifiers() {
            if let result = try indexes(on: TableIdentifier(schemaID: schemaIdentifier, name: tableName)) {
                return result
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    /// Returns nil if table does not exist
    private func indexes(on table: TableIdentifier) throws -> [IndexInfo]? {
        if let indexes = schemaCache[table.schemaID].indexes(on: table.name) {
            return indexes.value
        }
        
        let indexes = try Row
            // [seq:0 name:"index" unique:0 origin:"c" partial:0]
            .fetchAll(self, sql: "PRAGMA \(table.schemaID.sql).index_list(\(table.name.quotedDatabaseIdentifier))")
            .compactMap { row -> IndexInfo? in
                let indexName: String = row[1]
                let unique: Bool = row[2]
                
                let indexInfoRows = try Row
                    // [seqno:0 cid:2 name:"column"]
                    .fetchAll(self, sql: """
                        PRAGMA \(table.schemaID.sql).index_info(\(indexName.quotedDatabaseIdentifier))
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
                return IndexInfo(name: indexName, columns: columns, unique: unique)
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
    
    /// True if a sequence of columns uniquely identifies a row, that is to say
    /// if the columns are the primary key, or if there is a unique index on them.
    public func table<T: Sequence>(
        _ tableName: String,
        hasUniqueKey columns: T)
    throws -> Bool
    where T.Iterator.Element == String
    {
        try columnsForUniqueKey(Array(columns), in: tableName) != nil
    }
    
    /// The foreign keys defined on table named `tableName`.
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func foreignKeys(on tableName: String) throws -> [ForeignKeyInfo] {
        for schemaIdentifier in try schemaIdentifiers() {
            if let result = try foreignKeys(on: TableIdentifier(schemaID: schemaIdentifier, name: tableName)) {
                return result
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    /// Returns nil if table does not exist
    private func foreignKeys(on table: TableIdentifier) throws -> [ForeignKeyInfo]? {
        if let foreignKeys = schemaCache[table.schemaID].foreignKeys(on: table.name) {
            return foreignKeys.value
        }
        
        var rawForeignKeys: [(
            id: Int,
            destinationTable: String,
            mapping: [(origin: String, destination: String?, seq: Int)])] = []
        var previousId: Int? = nil
        for row in try Row.fetchAll(self, sql: """
            PRAGMA \(table.schemaID.sql).foreign_key_list(\(table.name.quotedDatabaseIdentifier))
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
    public func foreignKeyViolations(in tableName: String) throws -> RecordCursor<ForeignKeyViolation> {
        for schemaIdentifier in try schemaIdentifiers() {
            if try exists(type: .table, name: tableName, in: schemaIdentifier) {
                return try foreignKeyViolations(in: TableIdentifier(schemaID: schemaIdentifier, name: tableName))
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    /// Throws a DatabaseError of extended code `SQLITE_CONSTRAINT_FOREIGNKEY`
    /// if there exists a foreign key violation in the database.
    public func checkForeignKeys() throws {
        try checkForeignKeys(from: foreignKeyViolations())
    }
    
    /// Throws a DatabaseError of extended code `SQLITE_CONSTRAINT_FOREIGNKEY`
    /// if there exists a foreign key violation in the table.
    public func checkForeignKeys(in tableName: String) throws {
        try checkForeignKeys(from: foreignKeyViolations(in: tableName))
    }
    
    private func foreignKeyViolations(in table: TableIdentifier) throws -> RecordCursor<ForeignKeyViolation> {
        try ForeignKeyViolation.fetchCursor(self, sql: """
            PRAGMA \(table.schemaID.sql).foreign_key_check(\(table.name.quotedDatabaseIdentifier))
            """)
    }
    
    private func checkForeignKeys(from violations: RecordCursor<ForeignKeyViolation>) throws {
        if let violation = try violations.next() {
            throw violation.databaseError(self)
        }
    }
    
    /// Returns the actual name of the database table, in the main or temp
    /// schema, or nil if the table does not exist.
    ///
    /// - throws: A DatabaseError if table does not exist.
    func canonicalTableName(_ tableName: String) throws -> String? {
        for schemaIdentifier in try schemaIdentifiers() {
            if let result = try schema(schemaIdentifier).canonicalName(tableName, ofType: .table) {
                return result
            }
        }
        return nil
    }
    
    func schema(_ schemaID: SchemaIdentifier) throws -> SchemaInfo {
        if let schemaInfo = schemaCache[schemaID].schemaInfo {
            return schemaInfo
        }
        let schemaInfo = try SchemaInfo(self, masterTableName: schemaID.masterTableName)
        schemaCache[schemaID].schemaInfo = schemaInfo
        return schemaInfo
    }
}

extension Database {
    
    /// The columns in the table, or view, named `tableName`.
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func columns(in tableName: String) throws -> [ColumnInfo] {
        for schemaIdentifier in try schemaIdentifiers() {
            if let result = try columns(in: TableIdentifier(schemaID: schemaIdentifier, name: tableName)) {
                return result
            }
        }
        throw DatabaseError.noSuchTable(tableName)
    }
    
    /// Returns nil if table does not exist
    private func columns(in table: TableIdentifier) throws -> [ColumnInfo]? {
        if let columns = schemaCache[table.schemaID].columns(in: table.name) {
            return columns.value
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
            if sqlite3_libversion_number() < 3008005 {
                // Work around a bug in SQLite where PRAGMA table_info would
                // return a result even after the table was deleted.
                if try !tableExists(table) {
                    schemaCache[table.schemaID].set(columns: .missing, forTable: table.name)
                    return nil
                }
            }
            columnInfoQuery = "PRAGMA \(table.schemaID.sql).table_info(\(table.name.quotedDatabaseIdentifier))"
        } else {
            // Use PRAGMA table_xinfo so that we can load generated columns
            columnInfoQuery = "PRAGMA \(table.schemaID.sql).table_xinfo(\(table.name.quotedDatabaseIdentifier))"
        }
        let columns = try ColumnInfo
            .fetchAll(self, sql: columnInfoQuery)
            .filter {
                // Purpose: keep generated columns, but discard hidden ones.
                // The "hidden" column magic numbers come from the SQLite
                // source code. The values 2 and 3 refer to virtual and stored
                // generated columns, respectively, and 1 refer to hidden one.
                // Search for COLFLAG_HIDDEN in
                // https://www.sqlite.org/cgi/src/file?name=src/pragma.c&ci=fca8dc8b578f215a
                $0.hidden != 1
            }
            .sorted(by: { $0.cid < $1.cid })
        if columns.isEmpty {
            // Table does not exist
            schemaCache[table.schemaID].set(columns: .missing, forTable: table.name)
            return nil
        }
        
        schemaCache[table.schemaID].set(columns: .value(columns), forTable: table.name)
        return columns
    }
    
    /// If there exists a unique key on columns, return the columns
    /// ordered as the matching index (or primary key). Case of returned columns
    /// is not guaranteed.
    func columnsForUniqueKey<T: Sequence>(
        _ columns: T,
        in tableName: String)
    throws -> [String]?
    where T.Iterator.Element == String
    {
        let lowercasedColumns = Set(columns.map { $0.lowercased() })
        if lowercasedColumns.isEmpty {
            // Don't hit the database for trivial case
            return nil
        }
        
        // Assume "rowid" is a primary key
        if lowercasedColumns == ["rowid"] {
            return ["rowid"]
        }
        
        // Check primaryKey.
        let primaryKey = try self.primaryKey(tableName)
        if Set(primaryKey.columns.map { $0.lowercased() }).isSubset(of: lowercasedColumns) {
            return primaryKey.columns
        }
        
        // Is there is an explicit unique index on the columns?
        let indexes = try self.indexes(on: tableName)
        let matchingIndex = indexes.first { index in
            index.isUnique && Set(index.columns.map { $0.lowercased() }).isSubset(of: lowercasedColumns)
        }
        if let index = matchingIndex {
            return index.columns
        }
        return nil
    }
    
    /// Returns the columns to check for NULL in order to check if the row exist.
    ///
    /// The returned array is never empty.
    func existenceCheckColumns(in tableName: String) throws -> [String] {
        if try tableExists(tableName) {
            // Table: only check the primary key columns for existence
            let primaryKey = try self.primaryKey(tableName)
            if let rowIDColumn = primaryKey.rowIDColumn {
                // Prefer the user-provided name of the rowid
                return [rowIDColumn]
            } else if primaryKey.tableHasRowID {
                // Prefer the rowid
                return [Column.rowID.name]
            } else {
                // WITHOUT ROWID table: use primary key columns
                return primaryKey.columns
            }
        } else {
            // View: check all columns for existence
            return try columns(in: tableName).map(\.name)
        }
    }
}

/// A column of a database table.
///
/// This type closely matches the information returned by the
/// `table_info` and `table_xinfo` pragmas.
///
///     sqlite> CREATE TABLE player (
///        ...>   id INTEGER PRIMARY KEY,
///        ...>   firstName TEXT,
///        ...>   lastName TEXT);
///     sqlite> PRAGMA table_info(player);
///     cid     name        type        notnull     dflt_value  pk
///     ------  ----------  ----------  ----------  ----------  -----
///     0       id          INTEGER     0                       1
///     1       firstName   TEXT        0                       0
///     2       lastName    TEXT        0                       0
///     sqlite> PRAGMA table_xinfo(player);
///     cid     name        type        notnull     dflt_value  pk     hidden
///     ------  ----------  ----------  ----------  ----------  -----  ----------
///     0       id          INTEGER     0                       1      0
///     1       firstName   TEXT        0                       0      0
///     2       lastName    TEXT        0                       0      0
///
/// See `Database.columns(in:)` and <https://www.sqlite.org/pragma.html#pragma_table_info>
public struct ColumnInfo: FetchableRecord {
    let cid: Int
    let hidden: Int?
    
    /// The column name
    public let name: String
    
    /// The column data type
    ///
    /// The casing of this string depends on the SQLite version: make sure you
    /// process this string in a case-insensitive way.
    public let type: String
    
    /// True if and only if the column is constrained to be not null.
    public let isNotNull: Bool
    
    /// The SQL snippet that defines the default value, if any.
    ///
    /// When nil, the column has no default value.
    ///
    /// When not nil, it contains an SQL string that defines an expression. That
    /// expression may be a literal, as `1`, or `'foo'`. It may also contain a
    /// non-constant expression such as `CURRENT_TIMESTAMP`.
    ///
    /// For example:
    ///
    ///     try db.execute(sql: """
    ///         CREATE TABLE player(
    ///             id INTEGER PRIMARY KEY,
    ///             name TEXT DEFAULT 'Anonymous',
    ///             score INT DEFAULT 0,
    ///             creationDate DATE DEFAULT CURRENT_TIMESTAMP
    ///         )
    ///         """)
    ///     let columnInfos = try db.columns(in: "player")
    ///     columnInfos[0].defaultValueSQL // nil
    ///     columnInfos[1].defaultValueSQL // "'Anoynymous'"
    ///     columnInfos[2].defaultValueSQL // "0"
    ///     columnInfos[3].defaultValueSQL // "CURRENT_TIMESTAMP"
    public let defaultValueSQL: String?
    
    /// Zero for columns that are not part of the primary key.
    ///
    /// Before SQLite 3.7.16, it is 1 for columns that are part of the
    /// primary key.
    ///
    /// Starting from SQLite 3.7.16, it is the one-based index of the column in
    /// the primary key for columns that are part of the primary key.
    ///
    /// References:
    /// - <https://sqlite.org/releaselog/3_7_16.html>
    /// - <http://mailinglists.sqlite.org/cgi-bin/mailman/private/sqlite-users/2013-April/046034.html>
    public let primaryKeyIndex: Int
    
    /// :nodoc:
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

/// An index on a database table.
///
/// See `Database.indexes(on:)`
public struct IndexInfo {
    /// The name of the index
    public let name: String
    
    /// The indexed columns
    public let columns: [String]
    
    /// True if the index is unique
    public let isUnique: Bool
    
    init(name: String, columns: [String], unique: Bool) {
        self.name = name
        self.columns = columns
        self.isUnique = unique
    }
}

/// A foreign key violation produced by PRAGMA foreign_key_check
///
/// See <https://www.sqlite.org/pragma.html#pragma_foreign_key_check>
public struct ForeignKeyViolation: FetchableRecord, CustomStringConvertible {
    /// The name of the table that contains the `REFERENCES` clause
    public var originTable: String
    
    /// The rowid of the row that contains the invalid `REFERENCES` clause, or
    /// nil if the origin table is a `WITHOUT ROWID` table.
    public var originRowID: Int64?
    
    /// The name of the table that is referred to.
    public var destinationTable: String
    
    /// The id of the specific foreign key constraint that failed. This id
    /// matches `ForeignKeyInfo.id`. See `Database.foreignKeys(on:)` for more
    /// information.
    public var foreignKeyId: Int
    
    public init(row: Row) {
        originTable = row[0]
        originRowID = row[1]
        destinationTable = row[2]
        foreignKeyId = row[3]
    }
    
    public var description: String {
        if let originRowID = originRowID {
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
    
    /// Returns a precise description of the foreign key violation.
    ///
    /// For example: 'FOREIGN KEY constraint violation - from player(teamId) to team(id),
    /// in [id:1 teamId:2 name:"O'Brien" score: 1000]'
    public func failureDescription(_ db: Database) throws -> String {
        // Grab detailed information, if possible, for better error message
        let originRow = try originRowID.flatMap { rowid in
            try Row.fetchOne(db, sql: "SELECT * FROM \(originTable.quotedDatabaseIdentifier) WHERE rowid = \(rowid)")
        }
        let foreignKey = try db.foreignKeys(on: originTable).first(where: { foreignKey in
            foreignKey.id == foreignKeyId
        })
        
        var description: String
        if let foreignKey = foreignKey {
            description = """
                FOREIGN KEY constraint violation - \
                from \(originTable)(\(foreignKey.originColumns.joined(separator: ", "))) \
                to \(destinationTable)(\(foreignKey.destinationColumns.joined(separator: ", ")))
                """
        } else {
            description = "FOREIGN KEY constraint violation - from \(originTable) to \(destinationTable)"
        }
        
        if let originRow = originRow {
            description += ", in \(String(describing: originRow))"
        } else if let originRowID = originRowID {
            description += ", in rowid \(originRowID)"
        }
        
        return description
    }
    
    /// Returns a DatabaseError of extended code `SQLITE_CONSTRAINT_FOREIGNKEY`
    public func databaseError(_ db: Database) -> DatabaseError {
        // Grab detailed information, if possible, for better error message.
        // If detailed information is not available, fallback to plain description.
        let message = (try? failureDescription(db)) ?? String(describing: self)
        return DatabaseError(
            resultCode: .SQLITE_CONSTRAINT_FOREIGNKEY,
            message: message)
    }
}

/// Primary keys are returned from the Database.primaryKey(_:) method.
///
/// When the table's primary key is the rowid:
///
///     // CREATE TABLE item (name TEXT)
///     let pk = try db.primaryKey("item")
///     pk.columns     // ["rowid"]
///     pk.rowIDColumn // nil
///     pk.isRowID     // true
///
///     // CREATE TABLE citizen (
///     //   id INTEGER PRIMARY KEY,
///     //   name TEXT
///     // )
///     let pk = try db.primaryKey("citizen")!
///     pk.columns     // ["id"]
///     pk.rowIDColumn // "id"
///     pk.isRowID     // true
///
/// When the table's primary key is not the rowid:
///
///     // CREATE TABLE country (
///     //   isoCode TEXT NOT NULL PRIMARY KEY
///     //   name TEXT
///     // )
///     let pk = db.primaryKey("country")!
///     pk.columns     // ["isoCode"]
///     pk.rowIDColumn // nil
///     pk.isRowID     // false
///
///     // CREATE TABLE citizenship (
///     //   citizenID INTEGER NOT NULL REFERENCES citizen(id)
///     //   countryIsoCode TEXT NOT NULL REFERENCES country(isoCode)
///     //   PRIMARY KEY (citizenID, countryIsoCode)
///     // )
///     let pk = db.primaryKey("citizenship")!
///     pk.columns     // ["citizenID", "countryIsoCode"]
///     pk.rowIDColumn // nil
///     pk.isRowID     // false
public struct PrimaryKeyInfo {
    private enum Impl {
        /// The hidden rowID.
        case hiddenRowID
        
        /// An INTEGER PRIMARY KEY column that aliases the Row ID.
        /// Associated string is the column name.
        case rowID(String)
        
        /// Any primary key, but INTEGER PRIMARY KEY.
        /// Associated strings are column names.
        case regular(columns: [String], tableHasRowID: Bool)
    }
    
    private let impl: Impl
    
    static func rowID(_ column: String) -> PrimaryKeyInfo {
        PrimaryKeyInfo(impl: .rowID(column))
    }
    
    static func regular(_ columns: [String], tableHasRowID: Bool) -> PrimaryKeyInfo {
        assert(!columns.isEmpty)
        return PrimaryKeyInfo(impl: .regular(columns: columns, tableHasRowID: tableHasRowID))
    }
    
    static let hiddenRowID = PrimaryKeyInfo(impl: .hiddenRowID)
    
    /// The columns in the primary key; this array is never empty.
    public var columns: [String] {
        switch impl {
        case .hiddenRowID:
            return [Column.rowID.name]
        case let .rowID(column):
            return [column]
        case let .regular(columns: columns, tableHasRowID: _):
            return columns
        }
    }
    
    /// When not nil, the name of the column that contains the INTEGER PRIMARY KEY.
    public var rowIDColumn: String? {
        switch impl {
        case .hiddenRowID:
            return nil
        case .rowID(let column):
            return column
        case .regular:
            return nil
        }
    }
    
    /// When true, the primary key is the rowid:
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
    
    /// When false, the table is a WITHOUT ROWID table
    var tableHasRowID: Bool {
        switch impl {
        case .hiddenRowID:
            return true
        case .rowID:
            return true
        case let .regular(columns: _, tableHasRowID: tableHasRowID):
            return tableHasRowID
        }
    }
    
    /// The name of the fastest primary key column
    ///
    /// Returns nil for WITHOUT ROWID tables with a multi-columns primary key
    var fastPrimaryKeyColumn: String? {
        if let rowIDColumn = rowIDColumn {
            // Prefer the user-provided name of the rowid
            return rowIDColumn
        } else if tableHasRowID {
            // Prefer the rowid
            return Column.rowID.name
        } else if columns.count == 1 {
            // WITHOUT ROWID table: use primary key column
            return columns[0]
        } else {
            return nil
        }
    }
}

/// You get foreign keys from table names, with the
/// `foreignKeys(on:)` method.
public struct ForeignKeyInfo {
    /// The first column in the output of the `foreign_key_list` pragma
    public var id: Int
    
    /// The name of the destination table
    public let destinationTable: String
    
    /// The column to column mapping
    public let mapping: [(origin: String, destination: String)]
    
    /// The origin columns
    public var originColumns: [String] {
        mapping.map(\.origin)
    }
    
    /// The destination columns
    public var destinationColumns: [String] {
        mapping.map(\.destination)
    }
}

enum SchemaObjectType: String {
    case index
    case table
    case trigger
    case view
}

struct SchemaInfo: Equatable {
    private var objects: Set<SchemaObject>
    
    /// - parameter masterTable: "sqlite_master" or "sqlite_temp_master"
    init(_ db: Database, masterTableName: String) throws { // swiftlint:disable:this inclusive_language
        objects = try Set(SchemaObject.fetchCursor(db, sql: """
            SELECT type, name, tbl_name, sql FROM \(masterTableName)
            """))
    }
    
    /// All names for a given type
    func names(ofType type: SchemaObjectType) -> Set<String> {
        objects.reduce(into: []) { (set, key) in
            if key.type == type.rawValue {
                set.insert(key.name)
            }
        }
    }
    
    /// Returns the canonical name of the object:
    ///
    ///     try db.execute(sql: "CREATE TABLE FooBar (...)")
    ///     try db.schema().canonicalName("foobar", ofType: .table) // "FooBar"
    func canonicalName(_ name: String, ofType type: SchemaObjectType) -> String? {
        let name = name.lowercased()
        return objects
            .first { $0.type == type.rawValue && $0.name.lowercased() == name }?
            .name
    }
    
    private struct SchemaObject: Codable, Hashable, FetchableRecord {
        var type: String
        var name: String
        var tbl_name: String?
        var sql: String?
    }
}
