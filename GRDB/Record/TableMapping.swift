#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #endif
#endif

/// Types that adopt TableMapping declare a particular relationship with
/// a database table.
///
/// Types that adopt both TableMapping and RowConvertible are granted with
/// built-in methods that allow to fetch instances identified by key:
///
///     Person.fetchOne(db, key: 123)  // Person?
///     Citizenship.fetchOne(db, key: ["personId": 12, "countryId": 45]) // Citizenship?
///
/// TableMapping is adopted by Record.
public protocol TableMapping {
    /// The name of the database table
    static var databaseTableName: String { get }
}

extension RowConvertible where Self: TableMapping {
    
    // MARK: - Fetching by Single-Column Primary Key
    
    /// Returns a sequence of records, given their primary keys.
    ///
    ///     let persons = Person.fetch(db, keys: [1, 2, 3]) // DatabaseSequence<Person>
    ///
    /// The order of records in the returned sequence is undefined.
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - keys: A sequence of primary keys.
    /// - returns: A sequence of records.
    public static func fetch<Sequence: Swift.Sequence where Sequence.Iterator.Element: DatabaseValueConvertible>(_ db: Database, keys: Sequence) -> DatabaseSequence<Self> {
        guard let statement = try! makeFetchByPrimaryKeyStatement(db, keys: keys) else {
            return DatabaseSequence.makeEmptySequence(inDatabase: db)
        }
        return fetch(statement)
    }
    
    /// Returns an array of records, given their primary keys.
    ///
    ///     let persons = Person.fetchAll(db, keys: [1, 2, 3]) // [Person]
    ///
    /// The order of records in the returned array is undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: An array of records.
    public static func fetchAll<Sequence: Swift.Sequence where Sequence.Iterator.Element: DatabaseValueConvertible>(_ db: Database, keys: Sequence) -> [Self] {
        guard let statement = try! makeFetchByPrimaryKeyStatement(db, keys: keys) else {
            return []
        }
        return fetchAll(statement)
    }
    
    /// Returns a single record given its primary key.
    ///
    ///     let person = Person.fetchOne(db, key: 123) // Person?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: An optional record.
    public static func fetchOne<PrimaryKeyType: DatabaseValueConvertible>(_ db: Database, key: PrimaryKeyType?) -> Self? {
        guard let key = key else {
            return nil
        }
        return try! fetchOne(makeFetchByPrimaryKeyStatement(db, keys: [key])!)
    }
    
    // Returns "SELECT * FROM table WHERE id IN (?,?,?)"
    //
    // Returns nil if values is empty.
    private static func makeFetchByPrimaryKeyStatement<Sequence: Swift.Sequence where Sequence.Iterator.Element: DatabaseValueConvertible>(_ db: Database, keys: Sequence) throws -> SelectStatement? {
        // Fail early if database table does not exist.
        let databaseTableName = self.databaseTableName
        let primaryKey = try db.primaryKey(databaseTableName)
        
        // Fail early if database table has not one column in its primary key
        let columns = primaryKey?.columns ?? []
        GRDBPrecondition(columns.count == 1, "requires single column primary key in table: \(databaseTableName)")
        let column = columns.first!
        
        let keys = Array(keys)
        switch keys.count {
        case 0:
            // Avoid performing useless SELECT
            return nil
        case 1:
            // SELECT * FROM table WHERE id = ?
            let sql = "SELECT * FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) = ?"
            let statement = try db.makeSelectStatement(sql)
            statement.arguments = StatementArguments(keys)
            return statement
        case let count:
            // SELECT * FROM table WHERE id IN (?,?,?)
            let keysSQL = databaseQuestionMarks(count: count)
            let sql = "SELECT * FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(column.quotedDatabaseIdentifier) IN (\(keysSQL))"
            let statement = try db.makeSelectStatement(sql)
            statement.arguments = StatementArguments(keys)
            return statement
        }
    }
}

extension TableMapping {
    
    // MARK: - Deleting by Single-Column Primary Key
    
    /// Delete records identified by their primary keys.
    ///
    ///     try Person.deleteAll(db, keys: [1, 2, 3])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: The number of deleted rows
    public static func deleteAll<Sequence: Swift.Sequence where Sequence.Iterator.Element: DatabaseValueConvertible>(_ db: Database, keys: Sequence) throws -> Int {
        guard let statement = try! makeDeleteByPrimaryKeyStatement(db, keys: keys) else {
            return 0
        }
        try statement.execute()
        return db.changesCount
    }
    
    /// Delete a record, identified by its primary key.
    ///
    ///     try Person.deleteOne(db, key: 123)
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: Whether a database row was deleted.
    public static func deleteOne<PrimaryKeyType: DatabaseValueConvertible>(_ db: Database, key: PrimaryKeyType?) throws -> Bool {
        guard let key = key else {
            return false
        }
        return try deleteAll(db, keys: [key]) > 0
    }
    
    // Returns "DELETE FROM table WHERE id IN (?,?,?)"
    //
    // Returns nil if keys is empty.
    private static func makeDeleteByPrimaryKeyStatement<Sequence: Swift.Sequence where Sequence.Iterator.Element: DatabaseValueConvertible>(_ db: Database, keys: Sequence) throws -> UpdateStatement? {
        // Fail early if database table does not exist.
        let databaseTableName = self.databaseTableName
        let primaryKey = try db.primaryKey(databaseTableName)
        
        // Fail early if database table has not one column in its primary key
        let columns = primaryKey?.columns ?? []
        GRDBPrecondition(columns.count == 1, "requires single column primary key in table: \(databaseTableName)")
        let column = columns.first!
        
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


extension RowConvertible where Self: TableMapping {

    // MARK: - Fetching by Key
    
    /// Returns a sequence of records, given an array of key dictionaries.
    ///
    ///     let persons = Person.fetch(db, keys: [["name": "Arthur"], ["name": "Barbara"]]) // DatabaseSequence<Person>
    ///
    /// The order of records in the returned sequence is undefined.
    ///
    /// - parameters:
    ///     - db: A Database.
    ///     - keys: An array of key dictionaries.
    /// - returns: A sequence of records.
    public static func fetch(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) -> DatabaseSequence<Self> {
        guard let statement = try! makeFetchByKeyStatement(db, keys: keys) else {
            return DatabaseSequence.makeEmptySequence(inDatabase: db)
        }
        return fetch(statement)
    }
    
    /// Returns an array of records, given an array of key dictionaries.
    ///
    ///     let persons = Person.fetchAll(db, keys: [["name": "Arthur"], ["name": "Barbara"]]) // [Person]
    ///
    /// The order of records in the returned array is undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: An array of records.
    public static func fetchAll(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) -> [Self] {
        guard let statement = try! makeFetchByKeyStatement(db, keys: keys) else {
            return []
        }
        return fetchAll(statement)
    }
    
    /// Returns a single record given a key dictionary.
    ///
    ///     let person = Person.fetchOne(db, key: ["name": Arthur"]) // Person?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: An optional record.
    public static func fetchOne(_ db: Database, key: [String: DatabaseValueConvertible?]) -> Self? {
        return try! fetchOne(makeFetchByKeyStatement(db, keys: [key])!)
    }
    
    // Returns "SELECT * FROM table WHERE (a = ? AND b = ?) OR (a = ? AND b = ?) ...
    //
    // Returns nil if keys is empty.
    //
    // If there is no unique index on the columns, the method raises a fatal
    // (unless fatalErrorOnMissingUniqueIndex is false, for testability).
    static func makeFetchByKeyStatement(_ db: Database, keys: [[String: DatabaseValueConvertible?]], fatalErrorOnMissingUniqueIndex: Bool = true) throws -> SelectStatement? {
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
            guard try db.columns(columns, uniquelyIdentifyRowsIn: databaseTableName) else {
                if fatalErrorOnMissingUniqueIndex {
                    fatalError("table \(databaseTableName) has no unique index on column(s) \(columns.joined(separator: ", "))")
                } else {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "table \(databaseTableName) has no unique index on column(s) \(columns.joined(separator: ", "))")
                }
            }
            arguments.append(contentsOf: dictionary.values)
            whereClauses.append("(" + (columns.map { "\($0.quotedDatabaseIdentifier) = ?" } as [String]).joined(separator: " AND ") + ")")
        }
        
        let whereClause = whereClauses.joined(separator: " OR ")
        let sql = "SELECT * FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(whereClause)"
        let statement = try! db.makeSelectStatement(sql)
        statement.arguments = StatementArguments(arguments)
        return statement
    }
}


extension TableMapping {

    // MARK: - Deleting by Key
    
    /// Delete records, given an array of key dictionaries.
    ///
    ///     try Person.deleteAll(db, keys: [["name": "Arthur"], ["name": "Barbara"]])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: The number of deleted rows
    public static func deleteAll(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> Int {
        guard let statement = try makeDeleteByKeyStatement(db, keys: keys) else {
            return 0
        }
        try statement.execute()
        return db.changesCount
    }
    
    /// Delete a record, identified by a key dictionary.
    ///
    ///     Person.deleteOne(db, key: ["name": Arthur"])
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: Whether a database row was deleted.
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
            guard try db.columns(columns, uniquelyIdentifyRowsIn: databaseTableName) else {
                if fatalErrorOnMissingUniqueIndex {
                    fatalError("table \(databaseTableName) has no unique index on column(s) \(columns.joined(separator: ", "))")
                } else {
                    throw DatabaseError(code: SQLITE_MISUSE, message: "table \(databaseTableName) has no unique index on column(s) \(columns.joined(separator: ", "))")
                }
            }
            arguments.append(contentsOf: dictionary.values)
            whereClauses.append("(" + (columns.map { "\($0.quotedDatabaseIdentifier) = ?" } as [String]).joined(separator: " AND ") + ")")
        }
        
        let whereClause = whereClauses.joined(separator: " OR ")
        let sql = "DELETE FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(whereClause)"
        let statement = try! db.makeUpdateStatement(sql)
        statement.arguments = StatementArguments(arguments)
        return statement
    }
}
