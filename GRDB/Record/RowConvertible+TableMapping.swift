extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching All
    
    /// A cursor over all records fetched from the database.
    ///
    ///     let persons = try Person.fetchCursor(db) // DatabaseCursor<Person>
    ///     while let person = try persons.next() {  // Person
    ///         ...
    ///     }
    ///
    /// Records are iterated in the natural ordering of the table.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// The cursor must be iterated in a protected dispath queue.
    ///
    /// - parameter db: A database connection.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database) throws -> DatabaseCursor<Self> {
        return try all().fetchCursor(db)
    }
    
    /// An array of all records fetched from the database.
    ///
    ///     let persons = try Person.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database) throws -> [Self] {
        return try all().fetchAll(db)
    }
    
    /// The first found record.
    ///
    ///     let person = try Person.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database) throws -> Self? {
        return try all().fetchOne(db)
    }
}

extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching by Single-Column Primary Key
    
    /// Returns a cursor over records, given their primary keys.
    ///
    ///     let persons = try Person.fetchCursor(db, keys: [1, 2, 3]) // DatabaseCursor<Person>
    ///     while let person = try persons.next() {
    ///         ...
    ///     }
    ///
    /// Records are iterated in unspecified order.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> DatabaseCursor<Self>? where Sequence.Iterator.Element: DatabaseValueConvertible {
        guard let request = try request(db, keys: keys) else {
            return nil
        }
        return try fetchCursor(db, request)
    }
    
    /// Returns an array of records, given their primary keys.
    ///
    ///     let persons = try Person.fetchAll(db, keys: [1, 2, 3]) // [Person]
    ///
    /// The order of records in the returned array is undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> [Self] where Sequence.Iterator.Element: DatabaseValueConvertible {
        guard let request = try request(db, keys: keys) else {
            return []
        }
        return try fetchAll(db, request)
    }
    
    /// Returns a single record given its primary key.
    ///
    ///     let person = try Person.fetchOne(db, key: 123) // Person?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne<PrimaryKeyType: DatabaseValueConvertible>(_ db: Database, key: PrimaryKeyType?) throws -> Self? {
        guard let key = key else {
            return nil
        }
        return try fetchOne(db, request(db, keys: [key])!)
    }
    
    // Returns nil if values is empty.
    private static func request<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) throws -> Request? where Sequence.Iterator.Element: DatabaseValueConvertible {
        let databaseTableName = self.databaseTableName
        let primaryKey = try db.primaryKey(databaseTableName)
        let columns = primaryKey?.columns ?? []
        GRDBPrecondition(columns.count <= 1, "requires single column primary key in table: \(databaseTableName)")
        let column = columns.first.map { Column($0) } ?? Column.rowID
        
        let keys = Array(keys)
        switch keys.count {
        case 0:
            return nil
        case 1:
            return filter(column == keys[0])
        default:
            return filter(keys.contains(column))
        }
    }
}

extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching by Key
    
    /// Returns a cursor over records identified by the provided unique keys
    /// (primary key or any key with a unique index on it).
    ///
    ///     let persons = try Person.fetchCursor(db, keys: [["email": "a@example.com"], ["email": "b@example.com"]]) // DatabaseCursor<Person>
    ///     while let person = try persons.next() { // Person
    ///         ...
    ///     }
    ///
    /// Records are iterated in unspecified order.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: A cursor over fetched records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> DatabaseCursor<Self>? {
        guard let request = try request(db, keys: keys) else {
            return nil
        }
        return try fetchCursor(db, request)
    }
    
    /// Returns an array of records identified by the provided unique keys
    /// (primary key or any key with a unique index on it).
    ///
    ///     let persons = try Person.fetchAll(db, keys: [["email": "a@example.com"], ["email": "b@example.com"]]) // [Person]
    ///
    /// The order of records in the returned array is undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: An array of records.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) throws -> [Self] {
        guard let request = try request(db, keys: keys) else {
            return []
        }
        return try fetchAll(db, request)
    }
    
    /// Returns a single record identified by a unique key (the primary key or
    /// any key with a unique index on it).
    ///
    ///     let person = try Person.fetchOne(db, key: ["name": Arthur"]) // Person?
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A dictionary of values.
    /// - returns: An optional record.
    /// - throws: A DatabaseError is thrown whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, key: [String: DatabaseValueConvertible?]) throws -> Self? {
        return try fetchOne(db, request(db, keys: [key])!)
    }
    
    // Returns nil if keys is empty.
    //
    // If there is no unique index on the columns, the method raises a fatal
    // (unless fatalErrorOnMissingUniqueIndex is false, for testability).
    static func request(_ db: Database, keys: [[String: DatabaseValueConvertible?]], fatalErrorOnMissingUniqueIndex: Bool = true) throws -> Request? {
        // Avoid performing useless SELECT
        guard keys.count > 0 else {
            return nil
        }
        
        let databaseTableName = self.databaseTableName
        let predicates: [SQLExpression] = try keys.map { key in
            GRDBPrecondition(key.count > 0, "Invalid empty key dictionary")
            let columns = Array(key.keys)
            guard let orderedColumns = try db.columnsForUniqueKey(columns, in: databaseTableName) else {
                let error = DatabaseError(resultCode: .SQLITE_MISUSE, message: "table \(databaseTableName) has no unique index on column(s) \(columns.sorted().joined(separator: ", "))")
                if fatalErrorOnMissingUniqueIndex {
                    // Programmer error
                    fatalError(error.description)
                } else {
                    throw error
                }
            }
            let keyPredicates = orderedColumns.map { column -> SQLExpression in
                let keyPart = key.first(where: { $0.0.lowercased() == column.lowercased() })!
                return Column(keyPart.0) == keyPart.1
            }
            return SQLBinaryOperator.and.join(keyPredicates)!
        }
        
        return filter(SQLBinaryOperator.or.join(predicates)!)
    }
}
