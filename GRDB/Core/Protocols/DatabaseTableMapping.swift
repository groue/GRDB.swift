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
    
    /// Fetches a sequence of values, given their primary keys.
    ///
    ///     let persons = Person.fetch(db, primaryKeys: [1, 2, 3]) // DatabaseSequence<Person>
    ///
    /// The order of values in the returned sequence is undefined.
    ///
    /// - parameter db: A Database.
    /// - parameter primaryKeys: An array of primary keys.
    /// - returns: A sequence.
    public static func fetch<Sequence: SequenceType where Sequence.Generator.Element: DatabaseValueConvertible>(db: Database, primaryKeys: Sequence) -> DatabaseSequence<Self> {
        if let statement = self.fetchByPrimaryKeyStatement(db, primaryKeys: primaryKeys) {
            return self.fetch(statement)
        } else {
            return DatabaseSequence()
        }
    }
    
    /// Fetches an array of values, given their primary keys.
    ///
    ///     let persons = Person.fetchAll(db, primaryKeys: [1, 2, 3]) // [Person]
    ///
    /// The order of values in the returned array is undefined.
    ///
    /// - parameter db: A Database.
    /// - parameter primaryKeys: A array of primary keys.
    /// - returns: An array.
    public static func fetchAll<Sequence: SequenceType where Sequence.Generator.Element: DatabaseValueConvertible>(db: Database, primaryKeys: Sequence) -> [Self] {
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
    public static func fetchOne<PrimaryKeyType: DatabaseValueConvertible>(db: Database, primaryKey: PrimaryKeyType?) -> Self? {
        guard let primaryKey = primaryKey else {
            return nil
        }
        return self.fetchOne(self.fetchByPrimaryKeyStatement(db, primaryKeys: [primaryKey])!)
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
    
    // Returns "SELECT * FROM table WHERE id IN (?,?,?)"
    //
    // Returns nil if primaryKeys is empty.
    private static func fetchByPrimaryKeyStatement<Sequence: SequenceType where Sequence.Generator.Element: DatabaseValueConvertible>(db: Database, primaryKeys: Sequence) -> SelectStatement? {
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
        
        let primaryKeys = primaryKeys.map { $0 as DatabaseValueConvertible? }
        
        switch primaryKeys.count {
        case 0:
            // Avoid performing useless SELECT
            return nil
        case 1:
            // Use '=' in SQL query
            let sql = "SELECT * FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(columns.first!.quotedDatabaseIdentifier) = ?"
            let statement = db.selectStatement(sql)
            statement.arguments = StatementArguments(primaryKeys)
            return statement
        default:
            // Use 'IN'
            let questionMarks = Array(count: primaryKeys.count, repeatedValue: "?").joinWithSeparator(",")
            let sql = "SELECT * FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(columns.first!.quotedDatabaseIdentifier) IN (\(questionMarks))"
            let statement = db.selectStatement(sql)
            statement.arguments = StatementArguments(primaryKeys)
            return statement
        }
    }
}
