// MARK: - AllColumns

/// AllColumns is the `*` in `SELECT *`.
///
/// You use AllColumns in your custom implementation of
/// TableRecord.databaseSelection.
///
/// For example:
///
///     struct Player : TableRecord {
///         static var databaseTableName = "player"
///         static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
///     }
///
///     // SELECT *, rowid FROM player
///     let request = Player.all()
public struct AllColumns {
    public init() { }
}

extension AllColumns: SQLSelectable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func resultColumnSQL(_ context: inout SQLGenerationContext) -> String {
        return "*"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func countedSQL(_ context: inout SQLGenerationContext) -> String {
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
    public func qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        return QualifiedAllColumns(alias: alias)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func columnCount(_ db: Database) throws -> Int {
        fatalError("Can't compute number of columns without an alias")
    }
}

// MARK: - QualifiedAllColumns

/// QualifiedAllColumns is the `t.*` in `SELECT t.*`.
struct QualifiedAllColumns {
    private let alias: TableAlias
    
    init(alias: TableAlias) {
        self.alias = alias
    }
}

extension QualifiedAllColumns: SQLSelectable {
    func resultColumnSQL(_ context: inout SQLGenerationContext) -> String {
        if let qualifier = context.qualifier(for: alias) {
            return qualifier.quotedDatabaseIdentifier + ".*"
        }
        return "*"
    }
    
    func countedSQL(_ context: inout SQLGenerationContext) -> String {
        // TODO: restore the check below.
        //
        // It is currently disabled because of AssociationAggregateTests.testHasManyIsEmpty:
        //
        //      let request = Team.having(Team.players.isEmpty)
        //      try XCTAssertEqual(request.fetchCount(db), 1)
        //
        // This should build the trivial count query `SELECT COUNT(*) FROM (SELECT ...)`
        //
        // Unfortunately, we don't support anonymous table aliases that would be
        // required here. Because we don't support anonymous tables aliases,
        // everything happens as if we wanted to generate
        // `SELECT COUNT(team.*) FROM (SELECT ...)`, which is invalid SQL.
        //
        // So let's always return `*`, and fix this later.
        
        // if context.qualifier(for: alias) != nil {
        //     // SELECT COUNT(t.*) is invalid SQL
        //     fatalError("Not implemented, or invalid query")
        // }
        
        return "*"
    }
    
    func count(distinct: Bool) -> SQLCount? {
        return nil
    }
    
    func qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        // Never requalify
        return self
    }
    
    func columnCount(_ db: Database) throws -> Int {
        return try db.columns(in: alias.tableName).count
    }
}

// MARK: - SQLAliasedExpression

struct SQLAliasedExpression: SQLSelectable {
    let expression: SQLExpression
    let name: String
    
    init(_ expression: SQLExpression, name: String) {
        self.expression = expression
        self.name = name
    }
    
    func resultColumnSQL(_ context: inout SQLGenerationContext) -> String {
        return expression.resultColumnSQL(&context) + " AS " + name.quotedDatabaseIdentifier
    }
    
    func countedSQL(_ context: inout SQLGenerationContext) -> String {
        return expression.countedSQL(&context)
    }
    
    func count(distinct: Bool) -> SQLCount? {
        return expression.count(distinct: distinct)
    }
    
    func qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        return SQLAliasedExpression(expression.qualifiedExpression(with: alias), name: name)
    }
    
    func columnCount(_ db: Database) throws -> Int {
        return 1
    }
}
