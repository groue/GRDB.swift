// MARK: - DatabaseStorable

protocol DatabaseStorable : DatabaseTableMapping {
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] { get }
}

// MARK: - DataMapper

/// DataMapper takes care of DatabaseStorable CRUD
final class DataMapper {
    
    /// The database
    let db: Database
    
    /// The rowModel type
    let storable: DatabaseStorable
    
    /// DataMapper keeps a copy the storable's storedDatabaseDictionary, so
    /// that this dictionary is built once whatever the database operation.
    /// It is guaranteed to have at least one (key, value) pair.
    let storedDatabaseDictionary: [String: DatabaseValueConvertible?]
    
    /// The table name
    let databaseTableName: String
    
    /// The table primary key
    let primaryKey: PrimaryKey
    
    
    // MARK: - Primary Key
    
    /**
    An excerpt from storedDatabaseDictionary whose keys are primary key
    columns.
    
    It is nil when storable has no primary key.
    */
    lazy var primaryKeyDictionary: [String: DatabaseValueConvertible?]? = { [unowned self] in
        let columns = self.primaryKey.columns
        guard columns.count > 0 else {
            return nil
        }
        let storedDatabaseDictionary = self.storedDatabaseDictionary
        var dictionary: [String: DatabaseValueConvertible?] = [:]
        for column in columns {
            dictionary[column] = storedDatabaseDictionary[column]
        }
        return dictionary
        }()
    
    /**
    An excerpt from storedDatabaseDictionary whose keys are primary key
    columns. It is able to resolve a row in the database.
    
    It is nil when the primaryKeyDictionary is nil or unable to identify a
    row in the database.
    */
    lazy var resolvingPrimaryKeyDictionary: [String: DatabaseValueConvertible?]? = { [unowned self] in
        // IMPLEMENTATION NOTE
        //
        // https://www.sqlite.org/lang_createtable.html
        //
        // > According to the SQL standard, PRIMARY KEY should always
        // > imply NOT NULL. Unfortunately, due to a bug in some early
        // > versions, this is not the case in SQLite. Unless the column
        // > is an INTEGER PRIMARY KEY or the table is a WITHOUT ROWID
        // > table or the column is declared NOT NULL, SQLite allows
        // > NULL values in a PRIMARY KEY column. SQLite could be fixed
        // > to conform to the standard, but doing so might break legacy
        // > applications. Hence, it has been decided to merely document
        // > the fact that SQLite allowing NULLs in most PRIMARY KEY
        // > columns.
        //
        // What we implement: we consider that the primary key is missing if
        // and only if *all* columns of the primary key are NULL.
        //
        // For tables with a single column primary key, we comply to the
        // SQL standard.
        //
        // For tables with multi-column primary keys, we let the user
        // store NULL in all but one columns of the primary key.
        
        guard let dictionary = self.primaryKeyDictionary else {
            return nil
        }
        for case let value? in dictionary.values {
            return dictionary
        }
        return nil
        }()
    
    
    // MARK: - Initializer
    
    init(_ db: Database, _ storable: DatabaseStorable) {
        // Fail early if databaseTable is nil (not overriden)
        guard let databaseTableName = storable.dynamicType.databaseTableName() else {
            fatalError("Nil returned from \(storable.dynamicType).databaseTableName")
        }

        // Fail early if database table does not exist.
        guard let primaryKey = db.primaryKeyForTable(named: databaseTableName) else {
            fatalError("Table \(databaseTableName) does not exist. See \(storable.dynamicType).databaseTableName")
        }

        // Fail early if storedDatabaseDictionary is empty (not overriden)
        let storedDatabaseDictionary = storable.storedDatabaseDictionary
        guard storedDatabaseDictionary.count > 0 else {
            fatalError("Invalid empty dictionary returned from \(storable.dynamicType).storedDatabaseDictionary")
        }
        
        self.db = db
        self.storable = storable
        self.storedDatabaseDictionary = storedDatabaseDictionary
        self.databaseTableName = databaseTableName
        self.primaryKey = primaryKey
    }
    
    
    // MARK: - Statement builders
    
    func insertStatement() throws -> UpdateStatement {
        let insertStatement = try db.updateStatement(DataMapper.insertSQL(tableName: databaseTableName, insertedColumns: Array(storedDatabaseDictionary.keys)))
        insertStatement.arguments = StatementArguments(storedDatabaseDictionary.values)
        return insertStatement
    }
    
    /// Returns nil if there is no column to update
    func updateStatement() throws -> UpdateStatement? {
        // Fail early if primary key does not resolve to a database row.
        guard let primaryKeyDictionary = resolvingPrimaryKeyDictionary else {
            fatalError("Invalid primary key in \(storable)")
        }
        
        // Don't update primary key columns
        var updatedDictionary = storedDatabaseDictionary
        for column in primaryKeyDictionary.keys {
            updatedDictionary.removeValueForKey(column)
        }
        
        // We need something to update.
        guard updatedDictionary.count > 0 else {
            return nil
        }
        
        // Update
        let updateStatement = try db.updateStatement(DataMapper.updateSQL(tableName: databaseTableName, updatedColumns: Array(updatedDictionary.keys), conditionColumns: Array(primaryKeyDictionary.keys)))
        updateStatement.arguments = StatementArguments(Array(updatedDictionary.values) + Array(primaryKeyDictionary.values))
        return updateStatement
    }
    
    func deleteStatement() throws -> UpdateStatement {
        // Fail early if primary key does not resolve to a database row.
        guard let primaryKeyDictionary = resolvingPrimaryKeyDictionary else {
            fatalError("Invalid primary key in \(storable)")
        }
        
        // Delete
        let deleteStatement = try db.updateStatement(DataMapper.deleteSQL(tableName: databaseTableName, conditionColumns: Array(primaryKeyDictionary.keys)))
        deleteStatement.arguments = StatementArguments(primaryKeyDictionary.values)
        return deleteStatement
    }
    
    func reloadStatement() -> SelectStatement {
        // Fail early if primary key does not resolve to a database row.
        guard let primaryKeyDictionary = resolvingPrimaryKeyDictionary else {
            fatalError("Invalid primary key in \(storable)")
        }
        
        // Fetch
        let reloadStatement = db.selectStatement(DataMapper.reloadSQL(tableName: databaseTableName, conditionColumns: Array(primaryKeyDictionary.keys)))
        reloadStatement.arguments = StatementArguments(primaryKeyDictionary.values)
        return reloadStatement
    }
    
    /// SELECT statement that returns a row if and only if the primary key
    /// matches a row in the database.
    func existsStatement() -> SelectStatement {
        // Fail early if primary key does not resolve to a database row.
        guard let primaryKeyDictionary = resolvingPrimaryKeyDictionary else {
            fatalError("Invalid primary key in \(storable)")
        }
        
        // Fetch
        let existsStatement = db.selectStatement(DataMapper.existsSQL(tableName: databaseTableName, conditionColumns: Array(primaryKeyDictionary.keys)))
        existsStatement.arguments = StatementArguments(primaryKeyDictionary.values)
        return existsStatement
    }
    
    
    // MARK: - SQL query builders
    
    class func insertSQL(tableName tableName: String, insertedColumns: [String]) -> String {
        let columnSQL = insertedColumns.map { $0.quotedDatabaseIdentifier }.joinWithSeparator(",")
        let valuesSQL = [String](count: insertedColumns.count, repeatedValue: "?").joinWithSeparator(",")
        return "INSERT INTO \(tableName.quotedDatabaseIdentifier) (\(columnSQL)) VALUES (\(valuesSQL))"
    }
    
    class func updateSQL(tableName tableName: String, updatedColumns: [String], conditionColumns: [String]) -> String {
        let updateSQL = updatedColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joinWithSeparator(",")
        return "UPDATE \(tableName.quotedDatabaseIdentifier) SET \(updateSQL) WHERE \(whereSQL(conditionColumns))"
    }
    
    class func deleteSQL(tableName tableName: String, conditionColumns: [String]) -> String {
        return "DELETE FROM \(tableName.quotedDatabaseIdentifier) WHERE \(whereSQL(conditionColumns))"
    }
    
    class func existsSQL(tableName tableName: String, conditionColumns: [String]) -> String {
        return "SELECT 1 FROM \(tableName.quotedDatabaseIdentifier) WHERE \(whereSQL(conditionColumns))"
    }

    class func reloadSQL(tableName tableName: String, conditionColumns: [String]) -> String {
        return "SELECT * FROM \(tableName.quotedDatabaseIdentifier) WHERE \(whereSQL(conditionColumns))"
    }
    
    class func whereSQL(conditionColumns: [String]) -> String {
        return conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joinWithSeparator(" AND ")
    }
}
