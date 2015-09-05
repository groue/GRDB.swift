/**
Types that adopt DatabaseTableMapping can be initialized from rows that come
from a particular table.

The protocol comes with built-in  methods that allow to fetch instances
identified by their primary key, or any other key:

    Person.fetchOne(db, primaryKey: 123)  // Person?
    Citizenship.fetchOne(db, key: ["personId": 12, "countryId": 45]) // Citizenship?

DatabaseTableMapping is adopted by RowModel.
*/
public protocol DatabaseTableMapping : RowConvertible {
    static func databaseTableName() -> String?
}

extension DatabaseTableMapping {
    
    /**
    Fetches a single value by primary key.
    
        let person = Person.fetchOne(db, primaryKey: 123) // Person?
    
    - parameter db: A Database.
    - parameter primaryKey: A value.
    - returns: An optional value.
    */
    public static func fetchOne(db: Database, primaryKey primaryKeyValue: DatabaseValueConvertible?) -> Self? {
        // Fail early if databaseTable is nil (not overriden)
        guard let databaseTableName = self.databaseTableName() else {
            fatalError("Nil returned from \(self).databaseTableName")
        }
        
        // Fail early if database table does not exist.
        guard let primaryKey = db.primaryKeyForTable(named: databaseTableName) else {
            fatalError("Table \(databaseTableName) does not exist. See \(self).databaseTableName")
        }
        
        // Fail early if database table has not one column in its primary key
        let columns = primaryKey.columns
        guard columns.count == 1 else {
            if columns.count == 0 {
                fatalError("Table \(databaseTableName) has no primary key. See \(self).databaseTableName")
            } else {
                fatalError("Table \(databaseTableName) has a multi-column primary key. See \(self).databaseTableName")
            }
        }
        
        guard let primaryKeyValue = primaryKeyValue else {
            return nil
        }
        
        let sql = "SELECT * FROM \(databaseTableName.quotedDatabaseIdentifier) WHERE \(columns.first!.quotedDatabaseIdentifier) = ?"
        return fetchOne(db.selectStatement(sql), arguments: [primaryKeyValue])
    }
    
    /**
    Fetches a single value given a key.
    
        let person = Person.fetchOne(db, key: ["name": Arthur"]) // Person?
    
    - parameter db: A Database.
    - parameter key: A dictionary of values.
    - returns: An optional value.
    */
    public static func fetchOne(db: Database, key dictionary: [String: DatabaseValueConvertible?]) -> Self? {
        // Fail early if databaseTable is nil (not overriden)
        guard let databaseTableName = self.databaseTableName() else {
            fatalError("Nil returned from \(self).databaseTableName")
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
