extension Database {
    
    // MARK: - Database Schema
    
    /// Clears the database schema cache.
    ///
    /// You may need to clear the cache manually if the database schema is
    /// modified by another connection.
    public func clearSchemaCache() {
        SchedulingWatchdog.preconditionValidQueue(self)
        schemaCache.clear()
        
        // We also clear updateStatementCache and selectStatementCache despite
        // the automatic statement recompilation (see https://www.sqlite.org/c3ref/prepare.html)
        // because the automatic statement recompilation only happens a
        // limited number of times.
        internalStatementCache.clear()
        publicStatementCache.clear()
    }
    
    /// Clears the database schema cache if the database schema has changed
    /// since this method was last called.
    func clearSchemaCacheIfNeeded() throws {
        let schemaVersion = try Int32.fetchOne(internalCachedSelectStatement(sql: "PRAGMA schema_version"))
        if _lastSchemaVersion != schemaVersion {
            _lastSchemaVersion = schemaVersion
            clearSchemaCache()
        }
    }
    
    /// Returns whether a table exists.
    public func tableExists(_ name: String) throws -> Bool {
        try exists(type: .table, name: name)
    }
    
    /// Returns whether a table is an internal SQLite table.
    ///
    /// Those are tables whose name begins with `sqlite_` and `pragma_`.
    ///
    /// For more information, see https://www.sqlite.org/fileformat2.html
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
    /// For more information, see https://www.sqlite.org/fileformat2.html
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
    
    /// Returns whether a view exists.
    public func viewExists(_ name: String) throws -> Bool {
        try exists(type: .view, name: name)
    }
    
    /// Returns whether a trigger exists.
    public func triggerExists(_ name: String) throws -> Bool {
        try exists(type: .trigger, name: name)
    }
    
    private func exists(type: SchemaObjectType, name: String) throws -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving:
        // http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html
        let name = name.lowercased()
        return try schema()
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
        SchedulingWatchdog.preconditionValidQueue(self)
        
        if let primaryKey = schemaCache.primaryKey(tableName) {
            return primaryKey
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
        
        let columns = try self.columns(in: tableName)
        
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
                primaryKey = try .regular([pkColumn.name], tableHasRowID: tableHasRowID(tableName))
            }
        default:
            // Multi-columns primary key
            primaryKey = try .regular(pkColumns.map(\.name), tableHasRowID: tableHasRowID(tableName))
        }
        
        schemaCache.set(primaryKey: primaryKey, forTable: tableName)
        return primaryKey
    }
    
    /// Returns whether the column identifies the rowid column
    func columnIsRowID(_ column: String, of tableName: String) throws -> Bool {
        let pk = try primaryKey(tableName)
        return pk.rowIDColumn == column || (pk.tableHasRowID && column.uppercased() == "ROWID")
    }
    
    /// Returns whether the table has a rowid column.
    private func tableHasRowID(_ tableName: String) throws -> Bool {
        // Not need to cache the result, because this information feeds
        // `PrimaryKeyInfo`, which is cached.
        do {
            _ = try makeSelectStatement(sql: "SELECT rowid FROM \(tableName.quotedDatabaseIdentifier)")
            return true
        } catch DatabaseError.SQLITE_ERROR {
            return false
        }
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
    public func indexes(on tableName: String) throws -> [IndexInfo] {
        if let indexes = schemaCache.indexes(on: tableName) {
            return indexes
        }
        
        let indexes = try Row
            // [seq:0 name:"index" unique:0 origin:"c" partial:0]
            .fetchAll(self, sql: "PRAGMA index_list(\(tableName.quotedDatabaseIdentifier))")
            .compactMap { row -> IndexInfo? in
                let indexName: String = row[1]
                let unique: Bool = row[2]
                
                let indexInfoRows = try Row
                    // [seqno:0 cid:2 name:"column"]
                    .fetchAll(self, sql: "PRAGMA index_info(\(indexName.quotedDatabaseIdentifier))")
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
            if try tableExists(tableName) == false {
                throw DatabaseError(message: "no such table: \(tableName)")
            }
        }
        
        schemaCache.set(indexes: indexes, forTable: tableName)
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
    public func foreignKeys(on tableName: String) throws -> [ForeignKeyInfo] {
        if let foreignKeys = schemaCache.foreignKeys(on: tableName) {
            return foreignKeys
        }
        
        var rawForeignKeys: [(
            destinationTable: String,
            mapping: [(origin: String, destination: String?, seq: Int)])] = []
        var previousId: Int? = nil
        for row in try Row.fetchAll(self, sql: "PRAGMA foreign_key_list(\(tableName.quotedDatabaseIdentifier))") {
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
                rawForeignKeys.append((destinationTable: table, mapping: mapping))
                previousId = id
            }
        }
        
        if rawForeignKeys.isEmpty {
            // PRAGMA foreign_key_list doesn't throw any error when table does
            // not exist. So let's check if table exists:
            if try tableExists(tableName) == false {
                throw DatabaseError(message: "no such table: \(tableName)")
            }
        }
        
        let foreignKeys = try rawForeignKeys.map { (destinationTable, columnMapping) -> ForeignKeyInfo in
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
            return ForeignKeyInfo(destinationTable: destinationTable, mapping: completeMapping)
        }
        
        schemaCache.set(foreignKeys: foreignKeys, forTable: tableName)
        return foreignKeys
    }
    
    /// Returns the actual name of the database table
    func canonicalTableName(_ tableName: String) throws -> String {
        guard let name = try schema().canonicalName(tableName, ofType: .table) else {
            throw DatabaseError(message: "no such table: \(tableName)")
        }
        return name
    }
    
    func schema() throws -> SchemaInfo {
        if let schemaInfo = schemaCache.schemaInfo {
            return schemaInfo
        }
        let schemaInfo = try SchemaInfo(self)
        schemaCache.schemaInfo = schemaInfo
        return schemaInfo
    }
}

extension Database {
    
    /// The columns in the table named `tableName`
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func columns(in tableName: String) throws -> [ColumnInfo] {
        if let columns = schemaCache.columns(in: tableName) {
            return columns
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
                if try !tableExists(tableName) {
                    throw DatabaseError(message: "no such table: \(tableName)")
                }
            }
            columnInfoQuery = "PRAGMA table_info(\(tableName.quotedDatabaseIdentifier))"
        } else {
            // For our purposes, we look for generated columns, not hidden
            // columns. The "hidden" column magic numbers come from the SQLite
            // source code. The values 2 and 3 refer to virtual and stored
            // generated columns, respectively. Search for COLFLAG_VIRTUAL in
            // https://www.sqlite.org/cgi/src/file?name=src/pragma.c&ci=fca8dc8b578f215a
            columnInfoQuery = "SELECT * FROM pragma_table_xinfo('\(tableName)') WHERE hidden IN (0,2,3)"
        }
        let columns = try ColumnInfo
            .fetchAll(self, sql: columnInfoQuery)
            .sorted(by: { $0.cid < $1.cid })
        if columns.isEmpty {
            throw DatabaseError(message: "no such table: \(tableName)")
        }
        
        schemaCache.set(columns: columns, forTable: tableName)
        return columns
    }
    
    /// If there exists a unique key on columns, return the columns
    /// ordered as the matching index (or primay key). Case of returned columns
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
}

/// A column of a database table.
///
/// This type closely matches the information returned by the
/// `table_info` pragma.
///
///     > CREATE TABLE player (
///         id INTEGER PRIMARY KEY,
///         firstName TEXT,
///         lastName TEXT)
///     > PRAGMA table_info("player")
///     cid   name   type     notnull   dflt_value  pk
///     ----  -----  -------  --------  ----------  ---
///     0     id     INTEGER  0         NULL        1
///     1     name   TEXT     0         NULL        0
///     2     score  INTEGER  0         NULL        0
///
/// See `Database.columns(in:)` and https://www.sqlite.org/pragma.html#pragma_table_info
public struct ColumnInfo: DecodableRecord {
    let cid: Int
    
    /// The column name
    public let name: String
    
    /// The column data type
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
    /// - https://sqlite.org/releaselog/3_7_16.html
    /// - http://mailinglists.sqlite.org/cgi-bin/mailman/private/sqlite-users/2013-April/046034.html
    public let primaryKeyIndex: Int
    
    /// :nodoc:
    public init(row: Row) {
        cid = row["cid"]
        name = row["name"]
        type = row["type"]
        isNotNull = row["notnull"]
        defaultValueSQL = row["dflt_value"]
        primaryKeyIndex = row["pk"]
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
}

/// You get foreign keys from table names, with the
/// `foreignKeys(on:)` method.
public struct ForeignKeyInfo {
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
    
    init(_ db: Database) throws {
        objects = try Set(SchemaObject.fetchCursor(db, sql: """
            SELECT type, name, tbl_name, sql, 0 AS isTemporary FROM sqlite_master \
            UNION \
            SELECT type, name, tbl_name, sql, 1 FROM sqlite_temp_master
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
        return objects.first { $0.name.lowercased() == name }?.name
    }
    
    private struct SchemaObject: Codable, Hashable, DecodableRecord {
        var type: String
        var name: String
        var tbl_name: String?
        var sql: String?
        var isTemporary: Bool
    }
}
