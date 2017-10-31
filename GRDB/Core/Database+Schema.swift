#if SWIFT_PACKAGE
    import CSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
    import SQLite3
#endif

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
    
    /// Returns whether a table exists.
    public func tableExists(_ tableName: String) throws -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        return try Row.fetchOne(self, "SELECT 1 FROM (SELECT sql, type, name FROM sqlite_master UNION SELECT sql, type, name FROM sqlite_temp_master) WHERE type = 'table' AND LOWER(name) = ?", arguments: [tableName.lowercased()]) != nil
    }
    
    /// Returns whether a view exists.
    public func viewExists(_ viewName: String) throws -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        return try Row.fetchOne(self, "SELECT 1 FROM (SELECT sql, type, name FROM sqlite_master UNION SELECT sql, type, name FROM sqlite_temp_master) WHERE type = 'view' AND LOWER(name) = ?", arguments: [viewName.lowercased()]) != nil
    }
    
    /// Returns whether a trigger exists.
    public func triggerExists(_ triggerName: String) throws -> Bool {
        // SQlite identifiers are case-insensitive, case-preserving (http://www.alberton.info/dbms_identifiers_and_case_sensitivity.html)
        return try Row.fetchOne(self, "SELECT 1 FROM (SELECT sql, type, name FROM sqlite_master UNION SELECT sql, type, name FROM sqlite_temp_master) WHERE type = 'trigger' AND LOWER(name) = ?", arguments: [triggerName.lowercased()]) != nil
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
                primaryKey = .regular([pkColumn.name])
            }
        default:
            // Multi-columns primary key
            primaryKey = .regular(pkColumns.map { $0.name })
        }
        
        schemaCache.set(primaryKey: primaryKey, forTable: tableName)
        return primaryKey
    }
    
    /// The number of columns in the table named `tableName`.
    ///
    /// - throws: A DatabaseError if table does not exist.
    public func columnCount(in tableName: String) throws -> Int {
        return try columns(in: tableName).count
    }
    
    /// The indexes on table named `tableName`; returns the empty array if the
    /// table does not exist.
    ///
    /// Note: SQLite does not define any index for INTEGER PRIMARY KEY columns:
    /// this method does not return any index that represents this primary key.
    ///
    /// If you want to know if a set of columns uniquely identify a row, prefer
    /// table(_:hasUniqueKey:) instead.
    public func indexes(on tableName: String) throws -> [IndexInfo] {
        if let indexes = schemaCache.indexes(on: tableName) {
            return indexes
        }
        
        let indexes = try Row.fetchAll(self, "PRAGMA index_list(\(tableName.quotedDatabaseIdentifier))").map { row -> IndexInfo in
            let indexName: String = row[1]
            let unique: Bool = row[2]
            let columns = try Row.fetchAll(self, "PRAGMA index_info(\(indexName.quotedDatabaseIdentifier))")
                .map { ($0[0] as Int, $0[2] as String) }
                .sorted { $0.0 < $1.0 }
                .map { $0.1 }
            return IndexInfo(name: indexName, columns: columns, unique: unique)
        }
        
        schemaCache.set(indexes: indexes, forTable: tableName)
        return indexes
    }
    
    /// True if a sequence of columns uniquely identifies a row, that is to say
    /// if the columns are the primary key, or if there is a unique index on them.
    public func table<T: Sequence>(_ tableName: String, hasUniqueKey columns: T) throws -> Bool where T.Iterator.Element == String {
        return try columnsForUniqueKey(Array(columns), in: tableName) != nil
    }
    
    /// The foreign keys defined on table named `tableName`.
    public func foreignKeys(on tableName: String) throws -> [ForeignKeyInfo] {
        if let foreignKeys = schemaCache.foreignKeys(on: tableName) {
            return foreignKeys
        }
        
        var rawForeignKeys: [(destinationTable: String, mapping: [(origin: String, destination: String?, seq: Int)])] = []
        var previousId: Int? = nil
        for row in try Row.fetchAll(self, "PRAGMA foreign_key_list(\(tableName.quotedDatabaseIdentifier))") {
            // row = <Row id:0 seq:0 table:"parents" from:"parentId" to:"id" on_update:"..." on_delete:"..." match:"...">
            let id: Int = row[0]
            let seq: Int = row[1]
            let table: String = row[2]
            let origin: String = row[3]
            let destination: String? = row[4]
            
            if previousId == id {
                rawForeignKeys[rawForeignKeys.count - 1].mapping.append((origin: origin, destination: destination, seq: seq))
            } else {
                rawForeignKeys.append((destinationTable: table, mapping: [(origin: origin, destination: destination, seq: seq)]))
                previousId = id
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
}

extension Database {

    /// The columns in the table named `tableName`.
    ///
    /// - throws: A DatabaseError if table does not exist.
    func columns(in tableName: String) throws -> [ColumnInfo] {
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
        // CREATE TABLE players (
        //   id INTEGER PRIMARY KEY,
        //   firstName TEXT,
        //   lastName TEXT)
        //
        // PRAGMA table_info("players")
        //
        // cid | name  | type    | notnull | dflt_value | pk |
        // 0   | id    | INTEGER | 0       | NULL       | 1  |
        // 1   | name  | TEXT    | 0       | NULL       | 0  |
        // 2   | score | INTEGER | 0       | NULL       | 0  |

        if sqlite3_libversion_number() < 3008005 {
            // Work around a bug in SQLite where PRAGMA table_info would
            // return a result even after the table was deleted.
            if try !tableExists(tableName) {
                throw DatabaseError(message: "no such table: \(tableName)")
            }
        }
        let columns = try ColumnInfo.fetchAll(self, "PRAGMA table_info(\(tableName.quotedDatabaseIdentifier))")
        guard columns.count > 0 else {
            throw DatabaseError(message: "no such table: \(tableName)")
        }
        
        schemaCache.set(columns: columns, forTable: tableName)
        return columns
    }
    
    /// If there exists a unique key on columns, return the columns
    /// ordered as the matching index (or primay key). Case of returned columns
    /// is not guaranteed.
    func columnsForUniqueKey<T: Sequence>(_ columns: T, in tableName: String) throws -> [String]? where T.Iterator.Element == String {
        let primaryKey = try self.primaryKey(tableName) // first, so that we fail early and consistently should the table not exist
        let lowercasedColumns = Set(columns.map { $0.lowercased() })
        if Set(primaryKey.columns.map { $0.lowercased() }) == lowercasedColumns {
            return primaryKey.columns
        }
        if let index = try indexes(on: tableName).first(where: { index in index.isUnique && Set(index.columns.map { $0.lowercased() }) == lowercasedColumns }) {
            // There is an explicit unique index on the columns
            return index.columns
        }
        return nil
    }
}

/// A column of a table
struct ColumnInfo : RowConvertible {
    // CREATE TABLE players (
    //   id INTEGER PRIMARY KEY,
    //   firstName TEXT,
    //   lastName TEXT)
    //
    // PRAGMA table_info("players")
    //
    // cid | name  | type    | notnull | dflt_value | pk |
    // 0   | id    | INTEGER | 0       | NULL       | 1  |
    // 1   | name  | TEXT    | 0       | NULL       | 0  |
    // 2   | score | INTEGER | 0       | NULL       | 0  |
    let name: String
    let type: String
    let notNull: Bool
    let defaultDatabaseValue: DatabaseValue
    let primaryKeyIndex: Int
    
    init(row: Row) {
        name = row["name"]
        type = row["type"]
        notNull = row["notnull"]
        defaultDatabaseValue = row["dflt_value"]
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
///     // CREATE TABLE items (name TEXT)
///     let pk = try db.primaryKey("items")
///     pk.columns     // ["rowid"]
///     pk.rowIDColumn // nil
///     pk.isRowID     // true
///
///     // CREATE TABLE citizens (
///     //   id INTEGER PRIMARY KEY,
///     //   name TEXT
///     // )
///     let pk = try db.primaryKey("citizens")!
///     pk.columns     // ["id"]
///     pk.rowIDColumn // "id"
///     pk.isRowID     // true
///
/// When the table's primary key is not the rowid:
///
///     // CREATE TABLE countries (
///     //   isoCode TEXT NOT NULL PRIMARY KEY
///     //   name TEXT
///     // )
///     let pk = db.primaryKey("countries")!
///     pk.columns     // ["isoCode"]
///     pk.rowIDColumn // nil
///     pk.isRowID     // false
///
///     // CREATE TABLE citizenships (
///     //   citizenID INTEGER NOT NULL REFERENCES citizens(id)
///     //   countryIsoCode TEXT NOT NULL REFERENCES countries(isoCode)
///     //   PRIMARY KEY (citizenID, countryIsoCode)
///     // )
///     let pk = db.primaryKey("citizenships")!
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
        case regular([String])
    }
    
    private let impl: Impl
    
    static func rowID(_ column: String) -> PrimaryKeyInfo {
        return PrimaryKeyInfo(impl: .rowID(column))
    }
    
    static func regular(_ columns: [String]) -> PrimaryKeyInfo {
        assert(!columns.isEmpty)
        return PrimaryKeyInfo(impl: .regular(columns))
    }
    
    static let hiddenRowID = PrimaryKeyInfo(impl: .hiddenRowID)
    
    /// The columns in the primary key; this array is never empty.
    public var columns: [String] {
        switch impl {
        case .hiddenRowID:
            return [Column.rowID.name]
        case .rowID(let column):
            return [column]
        case .regular(let columns):
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
        return mapping.map { $0.origin }
    }
    
    /// The destination columns
    public var destinationColumns: [String] {
        return mapping.map { $0.destination }
    }
}
