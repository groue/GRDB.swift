extension FetchableRecord where Self: TableRecord {
    
    // MARK: Fetching All
    
    /// Returns a cursor over all records fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, TableRecord { }
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let players = try Player.fetchCursor(db)
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameter db: A database connection.
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database) throws -> RecordCursor<Self> {
        try all().fetchCursor(db)
    }
    
    /// Returns an array of all records fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, TableRecord { }
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let players = try Player.fetchAll(db)
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database) throws -> [Self] {
        try all().fetchAll(db)
    }
    
    /// Returns a single record fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, TableRecord { }
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player LIMIT 1
    ///     let player = try Player.fetchOne(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database) throws -> Self? {
        try all().fetchOne(db)
    }
}

extension FetchableRecord where Self: TableRecord & Hashable {
    /// Returns a set of all records fetched from the database.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, TableRecord, Hashable { }
    ///
    /// try dbQueue.read { db in
    ///     // SELECT * FROM player
    ///     let players = try Player.fetchSet(db)
    /// }
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(_ db: Database) throws -> Set<Self> {
        try all().fetchSet(db)
    }
}

extension FetchableRecord where Self: TableRecord {
    
    // MARK: Fetching by Single-Column Primary Key
    
    /// Returns a cursor over records identified by their primary keys.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchCursor(db, keys: [1, 2, 3])
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor<Keys>(_ db: Database, keys: Keys)
    throws -> RecordCursor<Self>
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        try filter(keys: keys).fetchCursor(db)
    }
    
    /// Returns an array of records identified by their primary keys.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchAll(db, keys: [1, 2, 3])
    ///     let countries = try Country.fetchAll(db, keys: ["FR", "US"])
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: An array of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll<Keys>(_ db: Database, keys: Keys)
    throws -> [Self]
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        let keys = Array(keys)
        if keys.isEmpty {
            // Avoid hitting the database
            return []
        }
        return try filter(keys: keys).fetchAll(db)
    }
    
    /// Returns the record identified by a primary key.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let player = try Player.fetchOne(db, key: 123)
    ///     let country = try Country.fetchOne(db, key: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: An optional record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, key: some DatabaseValueConvertible) throws -> Self? {
        if key.databaseValue.isNull {
            // Don't hit the database
            return nil
        }
        return try filter(key: key).fetchOne(db)
    }
    
    /// Returns the record identified by a primary key, or throws an error if
    /// the record does not exist.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let player = try Player.find(db, key: 123)
    ///     let country = try Country.find(db, key: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A primary key value.
    /// - returns: A record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or a
    ///   ``RecordError/recordNotFound(databaseTableName:key:)`` if the record
    ///   does not exist in the database.
    public static func find(_ db: Database, key: some DatabaseValueConvertible) throws -> Self {
        guard let record = try fetchOne(db, key: key) else {
            throw recordNotFound(db, key: key)
        }
        return record
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension FetchableRecord where Self: TableRecord & Identifiable, ID: DatabaseValueConvertible {
    
    // MARK: Fetching by Single-Column Primary Key
    
    /// Returns a cursor over records identified by their primary keys.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchCursor(db, ids: [1, 2, 3])
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor<IDS>(_ db: Database, ids: IDS)
    throws -> RecordCursor<Self>
    where IDS: Collection, IDS.Element == ID
    {
        try filter(ids: ids).fetchCursor(db)
    }
    
    /// Returns an array of records identified by their primary keys.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchAll(db, ids: [1, 2, 3])
    ///     let players = try Country.fetchAll(db, ids: ["FR", "US"])
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: An array of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll<IDS>(_ db: Database, ids: IDS) throws -> [Self]
    where IDS: Collection, IDS.Element == ID
    {
        if ids.isEmpty {
            // Avoid hitting the database
            return []
        }
        return try filter(ids: ids).fetchAll(db)
    }
    
    /// Returns the record identified by a primary key.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let player = try Player.fetchOne(db, id: 123)
    ///     let country = try Country.fetchOne(db, id: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: An optional record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, id: ID) throws -> Self? {
        try filter(id: id).fetchOne(db)
    }
    
    /// Returns the record identified by a primary key, or throws an error if
    /// the record does not exist.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let player = try Player.find(db, id: 123)
    ///     let country = try Country.find(db, id: "FR")
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - id: A primary key value.
    /// - returns: A record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or a
    ///   ``RecordError/recordNotFound(databaseTableName:key:)`` if the record
    ///   does not exist in the database.
    public static func find(_ db: Database, id: ID) throws -> Self {
        try find(db, key: id)
    }
}

extension FetchableRecord where Self: TableRecord & Hashable {
    /// Returns a set of records identified by their primary keys.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchSet(db, keys: [1, 2, 3])
    ///     let countries = try Country.fetchSet(db, keys: ["FR", "US"])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: A sequence of primary keys.
    /// - returns: A set of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet<Keys>(_ db: Database, keys: Keys)
    throws -> Set<Self>
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        let keys = Array(keys)
        if keys.isEmpty {
            // Avoid hitting the database
            return []
        }
        return try filter(keys: keys).fetchSet(db)
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension FetchableRecord where Self: TableRecord & Hashable & Identifiable, ID: DatabaseValueConvertible {
    /// Returns a set of records identified by their primary keys.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchSet(db, ids: [1, 2, 3])
    ///     let countries = try Country.fetchSet(db, ids: ["FR", "US"])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - ids: A collection of primary keys.
    /// - returns: A set of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet<IDS>(_ db: Database, ids: IDS) throws -> Set<Self>
    where IDS: Collection, IDS.Element == ID
    {
        if ids.isEmpty {
            // Avoid hitting the database
            return []
        }
        return try filter(ids: ids).fetchSet(db)
    }
}

extension FetchableRecord where Self: TableRecord {
    
    // MARK: Fetching by Key
    
    /// Returns a cursor over records identified by the provided unique keys
    /// (primary key or any key with a unique index on it).
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchCursor(db, keys: [
    ///         ["email": "a@example.com"],
    ///         ["email": "b@example.com"]])
    ///     while let player = try players.next() {
    ///         print(player.name)
    ///     }
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// The returned cursor is valid only during the remaining execution of the
    /// database access. Do not store or return the cursor for later use.
    ///
    /// If the database is modified during the cursor iteration, the remaining
    /// elements are undefined.
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: A ``RecordCursor`` over fetched records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchCursor(_ db: Database, keys: [[String: (any DatabaseValueConvertible)?]])
    throws -> RecordCursor<Self>
    {
        try filter(keys: keys).fetchCursor(db)
    }
    
    /// Returns an array of records identified by the provided unique keys
    /// (primary key or any key with a unique index on it).
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchAll(db, keys: [
    ///         ["email": "a@example.com"],
    ///         ["email": "b@example.com"]])
    /// }
    /// ```
    ///
    /// The order in which the records are returned is undefined
    /// ([ref](https://www.sqlite.org/lang_select.html#the_order_by_clause)).
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: An array of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchAll(_ db: Database, keys: [[String: (any DatabaseValueConvertible)?]]) throws -> [Self] {
        if keys.isEmpty {
            // Avoid hitting the database
            return []
        }
        return try filter(keys: keys).fetchAll(db)
    }
    
    /// Returns the record identified by a unique key (the primary key or
    /// any key with a unique index on it).
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let player = try Player.fetchOne(db, key: ["name": "Arthur"])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A key dictionary.
    /// - returns: An optional record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchOne(_ db: Database, key: [String: (any DatabaseValueConvertible)?]?) throws -> Self? {
        guard let key else {
            // Avoid hitting the database
            return nil
        }
        return try filter(key: key).fetchOne(db)
    }
    
    /// Returns the record identified by a unique key (the primary key or
    /// any key with a unique index on it), or throws an error if the record
    /// does not exist.
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let player = try Player.find(db, key: ["name": "Arthur"])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - key: A key dictionary.
    /// - returns: A record.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs, or a
    ///   ``RecordError/recordNotFound(databaseTableName:key:)`` if the record
    ///   does not exist in the database.
    public static func find(_ db: Database, key: [String: (any DatabaseValueConvertible)?]) throws -> Self {
        guard let record = try filter(key: key).fetchOne(db) else {
            throw recordNotFound(key: key)
        }
        return record
    }
}

extension FetchableRecord where Self: TableRecord & Hashable {
    /// Returns a set of records identified by the provided unique keys
    /// (primary key or any key with a unique index on it).
    ///
    /// For example:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let players = try Player.fetchSet(db, keys: [
    ///         ["email": "a@example.com"],
    ///         ["email": "b@example.com"]])
    /// }
    /// ```
    ///
    /// - parameters:
    ///     - db: A database connection.
    ///     - keys: An array of key dictionaries.
    /// - returns: A set of records.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func fetchSet(_ db: Database, keys: [[String: (any DatabaseValueConvertible)?]]) throws -> Set<Self> {
        if keys.isEmpty {
            // Avoid hitting the database
            return []
        }
        return try filter(keys: keys).fetchSet(db)
    }
}
