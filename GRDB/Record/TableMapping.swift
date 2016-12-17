#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

/// Types that adopt TableMapping declare a particular relationship with
/// a database table.
///
/// Types that adopt both TableMapping and RowConvertible are granted with
/// built-in methods that allow to fetch instances identified by key:
///
///     try Person.fetchOne(db, key: 123)  // Person?
///     try Citizenship.fetchOne(db, key: ["personId": 12, "countryId": 45]) // Citizenship?
///
/// TableMapping is adopted by Record.
public protocol TableMapping {
    /// The name of the database table
    static var databaseTableName: String { get }
    
    /// This flag tells whether the hidden "rowid" column should be fetched
    /// with other columns.
    ///
    /// Its default value is false:
    ///
    ///     // SELECT * FROM persons
    ///     try Person.fetchAll(db)
    ///
    /// When true, the rowid column is fetched:
    ///
    ///     // SELECT *, rowid FROM persons
    ///     try Person.fetchAll(db)
    static var selectsRowID: Bool { get }
}

extension TableMapping {
    /// Default value: false.
    public static var selectsRowID: Bool { return false }
}

extension TableMapping {
    
    // MARK: Counting All
    
    /// The number of records.
    ///
    /// - parameter db: A database connection.
    public static func fetchCount(_ db: Database) throws -> Int {
        return try all().fetchCount(db)
    }
}

extension TableMapping {
    
    // MARK: Deleting All
    
    /// Deletes all records; returns the number of deleted rows.
    ///
    /// - parameter db: A database connection.
    /// - returns: The number of deleted rows
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    @discardableResult
    public static func deleteAll(_ db: Database) throws -> Int {
        return try all().deleteAll(db)
    }
}

extension TableMapping {
    
    // MARK: Deleting by Single-Column Primary Key
    
    /// Delete records identified by their primary keys; returns the number of
    /// deleted rows.
    ///
    ///     try Person.deleteAll(db, keys: [1, 2, 3])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: The number of deleted rows
    @discardableResult
    public static func deleteAll<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> Int where Sequence.Iterator.Element: DatabaseValueConvertible {
        guard let statement = try makeDeleteByPrimaryKeyStatement(db, keys: keys) else {
            return 0
        }
        try statement.execute()
        return db.changesCount
    }
    
    /// Delete a record, identified by its primary key; returns whether a
    /// database row was deleted.
    ///
    ///     try Person.deleteOne(db, key: 123)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public static func deleteOne<PrimaryKeyType: DatabaseValueConvertible>(_ db: Database, key: PrimaryKeyType?) throws -> Bool {
        guard let key = key else {
            return false
        }
        return try deleteAll(db, keys: [key]) > 0
    }
    
    // Returns "DELETE FROM table WHERE id IN (?,?,?)"
    //
    // Returns nil if keys is empty.
    private static func makeDeleteByPrimaryKeyStatement<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> UpdateStatement? where Sequence.Iterator.Element: DatabaseValueConvertible {
        // Fail early if database table does not exist.
        let databaseTableName = self.databaseTableName
        let primaryKey = try db.primaryKey(databaseTableName)
        
        // Fail early if database table has not one column in its primary key
        let columns = primaryKey?.columns ?? []
        GRDBPrecondition(columns.count <= 1, "requires single column primary key in table: \(databaseTableName)")
        let column = columns.first ?? Column.rowID.name
        
        let keys = Array(keys)
        switch keys.count {
        case 0:
            // Avoid performing useless DELETE
            return nil
        case 1:
            // DELETE FROM table WHERE id = ?
            let sql = "DELETE FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) = ?"
            let statement = try db.makeUpdateStatement(sql)
            statement.arguments = StatementArguments(keys)
            return statement
        case let count:
            // DELETE FROM table WHERE id IN (?,?,?)
            let keysSQL = databaseQuestionMarks(count: count)
            let sql = "DELETE FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) IN (\(keysSQL))"
            let statement = try db.makeUpdateStatement(sql)
            statement.arguments = StatementArguments(keys)
            return statement
        }
    }
}

extension TableMapping {

    // MARK: Deleting by Key
    
    /// Delete records identified by the provided unique keys (primary key or
    /// any key with a unique index on it); returns the number of deleted rows.
    ///
    ///     try Person.deleteAll(db, keys: [["email": "a@example.com"], ["email": "b@example.com"]])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: The number of deleted rows
    @discardableResult
    public static func deleteAll(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> Int {
        guard let statement = try makeDeleteByKeyStatement(db, keys: keys) else {
            return 0
        }
        try statement.execute()
        return db.changesCount
    }
    
    /// Delete a record, identified by a unique key (the primary key or any key
    /// with a unique index on it); returns whether a database row was deleted.
    ///
    ///     Person.deleteOne(db, key: ["name": Arthur"])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: Whether a database row was deleted.
    @discardableResult
    public static func deleteOne(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Bool {
        return try deleteAll(db, keys: [key]) > 0
    }
    
    // Returns "DELETE FROM table WHERE (a = ? AND b = ?) OR (a = ? AND b = ?) ...
    //
    // Returns nil if keys is empty.
    //
    // If there is no unique index on the columns, the method raises a fatal
    // (unless fatalErrorOnMissingUniqueIndex is false, for testability).
    static func makeDeleteByKeyStatement(_ db: Database, keys: [[String: DatabaseValueConvertible?]], fatalErrorOnMissingUniqueIndex: Bool = true) throws -> UpdateStatement? {
        // Avoid performing useless SELECT
        guard keys.count > 0 else {
            return nil
        }
        
        let databaseTableName = self.databaseTableName
        var arguments: [DatabaseValueConvertible?] = []
        var whereClauses: [String] = []
        for dictionary in keys {
            GRDBPrecondition(dictionary.count > 0, "Invalid empty key dictionary")
            let columns = dictionary.keys
            guard try db.table(databaseTableName, hasUniqueKey: columns) else {
                let error = DatabaseError(code: SQLITE_MISUSE, message: "table \(databaseTableName) has no unique index on column(s) \(columns.joined(separator: ", "))")
                if fatalErrorOnMissingUniqueIndex {
                    fatalError(error.description)
                } else {
                    throw error
                }
            }
            arguments.append(contentsOf: dictionary.values)
            whereClauses.append("(" + (columns.map { "\($0.quotedDatabaseIdentifier) = ?" } as [String]).joined(separator: " AND ") + ")")
        }
        
        let whereClause = whereClauses.joined(separator: " OR ")
        let sql = "DELETE FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(whereClause)"
        let statement = try db.makeUpdateStatement(sql)
        statement.arguments = StatementArguments(arguments)
        return statement
    }
}

extension TableMapping {
    /// Returns a function that returns the primary key of a row.
    ///
    /// If the table has no primary key, and selectsRowID is true, use the
    /// "rowid" key.
    ///
    ///     try dbQueue.inDatabase { db in
    ///         let primaryKey = try Person.primaryKeyFunction(db)
    ///         let row = try Row.fetchOne(db, "SELECT * FROM persons")!
    ///         primaryKey(row) // ["id": 1]
    ///     }
    ///
    /// - throws: A DatabaseError if table does not exist.
    static func primaryKeyFunction(_ db: Database) throws -> (Row) -> [String: DatabaseValue] {
        let columns: [String]
        if let primaryKey = try db.primaryKey(databaseTableName) {
            columns = primaryKey.columns
        } else if selectsRowID {
            columns = ["rowid"]
        } else {
            columns = []
        }
        return { row in
            return Dictionary<String, DatabaseValue>(keys: columns) { row.value(named: $0) }
        }
    }
    
    /// Returns a function that returns true if and only if two rows have the
    /// same primary key and both primary keys contain at least one non-null
    /// value.
    ///
    ///     try dbQueue.inDatabase { db in
    ///         let comparator = try Person.primaryKeyRowComparator(db)
    ///         let row0 = Row(["id": nil, "name": "Unsaved"])
    ///         let row1 = Row(["id": 1, "name": "Arthur"])
    ///         let row2 = Row(["id": 1, "name": "Arthur"])
    ///         let row3 = Row(["id": 2, "name": "Barbara"])
    ///         comparator(row0, row0) // false
    ///         comparator(row1, row2) // true
    ///         comparator(row1, row3) // false
    ///     }
    ///
    /// - throws: A DatabaseError if table does not exist.
    static func primaryKeyRowComparator(_ db: Database) throws -> (Row, Row) -> Bool {
        let primaryKey = try primaryKeyFunction(db)
        return { (lhs, rhs) in
            let (lhs, rhs) = (primaryKey(lhs), primaryKey(rhs))
            guard lhs.contains(where: { !$1.isNull }) else { return false }
            guard rhs.contains(where: { !$1.isNull }) else { return false }
            return lhs == rhs
        }
    }
}
