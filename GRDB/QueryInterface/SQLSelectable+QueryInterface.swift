// MARK: - AllColumns

/// AllColumns is the `*` in `SELECT *`.
///
/// You use AllColumns in your custom implementation of
/// TableMapping.databaseSelection.
///
/// For example:
///
///     struct Player : TableMapping {
///         static var databaseTableName = "players"
///         static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
///     }
///
///     // SELECT *, rowid FROM players
///     let request = Player.all()
public struct AllColumns {
    private var qualifier: SQLTableQualifier?
    
    ///
    public init() { }
}

extension AllColumns : SQLSelectable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// :nodoc:
    public func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        if let qualifierName = qualifier?.name {
            return qualifierName.quotedDatabaseIdentifier + ".*"
        }
        return "*"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// :nodoc:
    public func countedSQL(_ arguments: inout StatementArguments?) -> String {
        guard qualifier == nil else {
            // SELECT COUNT(t.*) is invalid SQL
            fatalError("Not implemented, or invalid query")
        }
        return "*"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// :nodoc:
    public func count(distinct: Bool) -> SQLCount? {
        // SELECT DISTINCT * FROM tableName ...
        guard !distinct else {
            return nil
        }
        
        guard qualifier == nil else {
            return nil
        }
        
        // SELECT * FROM tableName ...
        // ->
        // SELECT COUNT(*) FROM tableName ...
        return .all
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// :nodoc:
    public func qualified(by qualifier: SQLTableQualifier) -> AllColumns {
        if self.qualifier != nil {
            // Never requalify
            return self
        }
        var allColumns = AllColumns()
        allColumns.qualifier = qualifier
        return allColumns
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// :nodoc:
    public func columnCount(_ db: Database) throws -> Int {
        guard let qualifier = qualifier else {
            fatalError("Can't compute number of columns without a qualifier")
        }
        return try db.columns(in: qualifier.tableName).count
    }
}


// MARK: - SQLAliasedExpression

struct SQLAliasedExpression : SQLSelectable {
    let expression: SQLExpression
    let alias: String
    
    init(_ expression: SQLExpression, alias: String) {
        self.expression = expression
        self.alias = alias
    }
    
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return expression.resultColumnSQL(&arguments) + " AS " + alias.quotedDatabaseIdentifier
    }
    
    func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return expression.countedSQL(&arguments)
    }
    
    func count(distinct: Bool) -> SQLCount? {
        return expression.count(distinct: distinct)
    }
    
    func qualified(by qualifier: SQLTableQualifier) -> SQLAliasedExpression {
        return SQLAliasedExpression(expression.qualified(by: qualifier), alias: alias)
    }
    
    func columnCount(_ db: Database) throws -> Int {
        return 1
    }
}
