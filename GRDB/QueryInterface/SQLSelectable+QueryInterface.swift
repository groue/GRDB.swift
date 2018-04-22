// MARK: - AllColumns

/// AllColumns is the `*` in `SELECT *`.
///
/// You use AllColumns in your custom implementation of
/// TableRecord.databaseSelection.
///
/// For example:
///
///     struct Player : TableRecord {
///         static var databaseTableName = "players"
///         static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
///     }
///
///     // SELECT *, rowid FROM players
///     let request = Player.all()
public struct AllColumns {
    public init() { }
}

extension AllColumns : SQLSelectable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return "*"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return "*"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func count(distinct: Bool) -> SQLCount? {
        // SELECT DISTINCT * FROM tableName ...
        if distinct {
            return nil
        }
        
        // SELECT * FROM tableName ...
        // ->
        // SELECT COUNT(*) FROM tableName ...
        return .all
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedSelectable(with qualifier: SQLTableQualifier) -> SQLSelectable {
        return QualifiedAllColumns(qualifier: qualifier)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func columnCount(_ db: Database) throws -> Int {
        fatalError("Can't compute number of columns without a qualifier")
    }
}

// MARK: - QualifiedAllColumns

/// QualifiedAllColumns is the `t.*` in `SELECT t.*`.
struct QualifiedAllColumns {
    private let qualifier: SQLTableQualifier
    
    init(qualifier: SQLTableQualifier) {
        self.qualifier = qualifier
    }
}

extension QualifiedAllColumns : SQLSelectable {
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        if let qualifierName = qualifier.name {
            return qualifierName.quotedDatabaseIdentifier + ".*"
        }
        return "*"
    }
    
    func countedSQL(_ arguments: inout StatementArguments?) -> String {
        // SELECT COUNT(t.*) is invalid SQL
        fatalError("Not implemented, or invalid query")
    }
    
    func count(distinct: Bool) -> SQLCount? {
        return nil
    }
    
    func qualifiedSelectable(with qualifier: SQLTableQualifier) -> SQLSelectable {
        // Never requalify
        return self
    }
    
    func columnCount(_ db: Database) throws -> Int {
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
    
    func qualifiedSelectable(with qualifier: SQLTableQualifier) -> SQLSelectable {
        return SQLAliasedExpression(expression.qualifiedExpression(with: qualifier), alias: alias)
    }
    
    func columnCount(_ db: Database) throws -> Int {
        return 1
    }
}
