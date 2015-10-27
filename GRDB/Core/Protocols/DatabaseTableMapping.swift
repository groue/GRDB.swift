/// Types that adopt DatabaseTableMapping can be initialized from rows that come
/// from a particular table.
///
/// The protocol comes with built-in methods that allow to fetch instances
/// identified by their primary key, or any other key:
///
///     Person.fetchOne(db, primaryKey: 123)  // Person?
///     Citizenship.fetchOne(db, key: ["personId": 12, "countryId": 45]) // Citizenship?
///
/// DatabaseTableMapping is adopted by Record.
public protocol DatabaseTableMapping : RowConvertible {
    static func databaseTableName() -> String?
}

extension DatabaseTableMapping {
    
    private static func fetchByPrimaryKeyStatement(db: Database, primaryKeys: [DatabaseValueConvertible]) -> SelectStatement? {
        // Fail early if databaseTable is nil
        guard let databaseTableName = self.databaseTableName() else {
            fatalError("Nil returned from \(self).databaseTableName()")
        }
        
        // Fail early if database table does not exist.
        guard let primaryKey = db.primaryKeyForTable(named: databaseTableName) else {
            fatalError("Table \(databaseTableName.quotedDatabaseIdentifier) does not exist. See \(self).databaseTableName()")
        }
        
        // Fail early if database table has not one column in its primary key
        let columns = primaryKey.columns
        guard columns.count == 1 else {
            fatalError("Primary key of table \(databaseTableName.quotedDatabaseIdentifier) is not made of a single column. See \(self).databaseTableName()")
        }
        
        // Avoid performing useless SELECT
        guard primaryKeys.count > 0 else {
            return nil
        }
        
        let questionMarks = Array(count: primaryKeys.count, repeatedValue: "?").joinWithSeparator(",")
        let sql = "SELECT * FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(columns.first!.quotedDatabaseIdentifier) IN (\(questionMarks))"
        let statement = db.selectStatement(sql)
        statement.arguments = StatementArguments(primaryKeys.map { $0 })
        return statement
    }
    
    /// Fetches a sequence of values, given their primary keys.
    ///
    ///     let persons = Person.fetch(db, primaryKeys:[1, 2, 3]) // DatabaseSequence<Person>
    ///
    /// The order of values in the sequence is undefined.
    ///
    /// - parameter db: A Database.
    /// - parameter primaryKey: A value.
    /// - returns: A sequence.
    public static func fetch(db: Database, primaryKeys: [DatabaseValueConvertible]) -> DatabaseSequence<Self> {
        if let statement = self.fetchByPrimaryKeyStatement(db, primaryKeys: primaryKeys) {
            return self.fetch(statement)
        } else {
            return DatabaseSequence()
        }
    }
    
    /// Fetches an array of values, given their primary keys.
    ///
    ///     let persons = Person.fetchAll(db, primaryKeys:[1, 2, 3]) // [Person]
    ///
    /// The order of values in the array is undefined.
    ///
    /// - parameter db: A Database.
    /// - parameter primaryKey: A value.
    /// - returns: An array.
    public static func fetchAll(db: Database, primaryKeys: [DatabaseValueConvertible]) -> [Self] {
        if let statement = self.fetchByPrimaryKeyStatement(db, primaryKeys: primaryKeys) {
            return self.fetchAll(statement)
        } else {
            return []
        }
    }
    
    /// Fetches a single value given its primary key.
    ///
    ///     let person = Person.fetchOne(db, primaryKey: 123) // Person?
    ///
    /// - parameter db: A Database.
    /// - parameter primaryKey: A value.
    /// - returns: An optional value.
    public static func fetchOne(db: Database, primaryKey: DatabaseValueConvertible?) -> Self? {
        let primaryKeys = primaryKey.map { [$0] } ?? []
        if let statement = self.fetchByPrimaryKeyStatement(db, primaryKeys: primaryKeys) {
            return self.fetchOne(statement)
        } else {
            return nil
        }
    }
    
    /// Fetches a single value given a key.
    ///
    ///     let person = Person.fetchOne(db, key: ["name": Arthur"]) // Person?
    ///
    /// - parameter db: A Database.
    /// - parameter key: A dictionary of values.
    /// - returns: An optional value.
    public static func fetchOne(db: Database, key dictionary: [String: DatabaseValueConvertible?]) -> Self? {
        // Fail early if databaseTable is nil
        guard let databaseTableName = self.databaseTableName() else {
            fatalError("Nil returned from \(self).databaseTableName()")
        }
        
        // Fail early if key is empty.
        guard dictionary.count > 0 else {
            fatalError("Invalid empty key")
        }
        
        let whereSQL = dictionary.keys.map { column in "\(column.quotedDatabaseIdentifier)=?" }.joinWithSeparator(" AND ")
        let sql = "SELECT * FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(whereSQL)"
        return fetchOne(db.selectStatement(sql), arguments: StatementArguments(dictionary.values))
    }
}
