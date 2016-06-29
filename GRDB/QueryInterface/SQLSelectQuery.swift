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


// MARK: - _SQLSelectQuery

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public struct _SQLSelectQuery {
    var selection: [_SQLSelectable]
    var isDistinct: Bool
    var source: _SQLSource?
    var whereExpression: _SQLExpression?
    var groupByExpressions: [_SQLExpression]
    var orderings: [_SQLOrdering]
    var isReversed: Bool
    var havingExpression: _SQLExpression?
    var limit: _SQLLimit?
    
    init(
        select selection: [_SQLSelectable],
        isDistinct: Bool = false,
        from source: _SQLSource? = nil,
        filter whereExpression: _SQLExpression? = nil,
        groupBy groupByExpressions: [_SQLExpression] = [],
        orderBy orderings: [_SQLOrdering] = [],
        isReversed: Bool = false,
        having havingExpression: _SQLExpression? = nil,
        limit: _SQLLimit? = nil)
    {
        self.selection = selection
        self.isDistinct = isDistinct
        self.source = source
        self.whereExpression = whereExpression
        self.groupByExpressions = groupByExpressions
        self.orderings = orderings
        self.isReversed = isReversed
        self.havingExpression = havingExpression
        self.limit = limit
    }
    
    func sql(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        var sql = "SELECT"
        
        if isDistinct {
            sql += " DISTINCT"
        }
        
        assert(!selection.isEmpty)
        sql += try " " + selection.map { try $0.resultColumnSQL(db, &arguments) }.joined(separator: ", ")
        
        if let source = source {
            sql += try " FROM " + source.sql(db, &arguments)
        }
        
        if let whereExpression = whereExpression {
            sql += try " WHERE " + whereExpression.sql(db, &arguments)
        }
        
        if !groupByExpressions.isEmpty {
            sql += try " GROUP BY " + groupByExpressions.map { try $0.sql(db, &arguments) }.joined(separator: ", ")
        }
        
        if let havingExpression = havingExpression {
            sql += try " HAVING " + havingExpression.sql(db, &arguments)
        }
        
        var orderings = self.orderings
        if isReversed {
            if orderings.isEmpty {
                // https://www.sqlite.org/lang_createtable.html#rowid
                //
                // > The rowid value can be accessed using one of the special
                // > case-independent names "rowid", "oid", or "_rowid_" in
                // > place of a column name. If a table contains a user defined
                // > column named "rowid", "oid" or "_rowid_", then that name
                // > always refers the explicitly declared column and cannot be
                // > used to retrieve the integer rowid value.
                //
                // Here we assume that _rowid_ is not a custom column.
                // TODO: support for user-defined _rowid_ column.
                // TODO: support for WITHOUT ROWID tables.
                orderings = [SQLColumn("_rowid_").desc]
            } else {
                orderings = orderings.map { $0.reversedOrdering }
            }
        }
        if !orderings.isEmpty {
            sql += try " ORDER BY " + orderings.map { try $0.orderingSQL(db, &arguments) }.joined(separator: ", ")
        }
        
        if let limit = limit {
            sql += " LIMIT " + limit.sql
        }
        
        return sql
    }
    
    /// Returns a query that counts the number of rows matched by self.
    var countQuery: _SQLSelectQuery {
        guard groupByExpressions.isEmpty && limit == nil else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            return trivialCountQuery
        }
        
        guard let source = source, case .table(name: let tableName, alias: let alias) = source else {
            // SELECT ... FROM (something which is not a table)
            return trivialCountQuery
        }
        
        assert(!selection.isEmpty)
        if selection.count == 1 {
            let selectable = self.selection[0]
            switch selectable.sqlSelectableKind {
            case .star(sourceName: let sourceName):
                guard !isDistinct else {
                    return trivialCountQuery
                }
                
                if let sourceName = sourceName {
                    guard sourceName == tableName || sourceName == alias else {
                        return trivialCountQuery
                    }
                }
                
                // SELECT * FROM tableName ...
                // ->
                // SELECT COUNT(*) FROM tableName ...
                var countQuery = unorderedQuery
                countQuery.selection = [_SQLExpression.count(selectable)]
                return countQuery
                
            case .expression(let expression):
                // SELECT [DISTINCT] expr FROM tableName ...
                if isDistinct {
                    // SELECT DISTINCT expr FROM tableName ...
                    // ->
                    // SELECT COUNT(DISTINCT expr) FROM tableName ...
                    var countQuery = unorderedQuery
                    countQuery.isDistinct = false
                    countQuery.selection = [_SQLExpression.countDistinct(expression)]
                    return countQuery
                } else {
                    // SELECT expr FROM tableName ...
                    // ->
                    // SELECT COUNT(*) FROM tableName ...
                    var countQuery = unorderedQuery
                    countQuery.selection = [_SQLExpression.count(_SQLResultColumn.star(nil))]
                    return countQuery
                }
            }
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
            
            guard !isDistinct else {
                return trivialCountQuery
            }

            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            var countQuery = unorderedQuery
            countQuery.selection = [_SQLExpression.count(_SQLResultColumn.star(nil))]
            return countQuery
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    private var trivialCountQuery: _SQLSelectQuery {
        return _SQLSelectQuery(
            select: [_SQLExpression.count(_SQLResultColumn.star(nil))],
            from: .query(query: unorderedQuery, alias: nil))
    }
    
    /// Remove ordering
    private var unorderedQuery: _SQLSelectQuery {
        var query = self
        query.isReversed = false
        query.orderings = []
        return query
    }
}


// MARK: - _SQLSource

indirect enum _SQLSource {
    case table(name: String, alias: String?)
    case query(query: _SQLSelectQuery, alias: String?)
    
    func sql(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        switch self {
        case .table(let table, let alias):
            if let alias = alias {
                return table.quotedDatabaseIdentifier + " AS " + alias.quotedDatabaseIdentifier
            } else {
                return table.quotedDatabaseIdentifier
            }
        case .query(let query, let alias):
            if let alias = alias {
                return try "(" + query.sql(db, &arguments) + ") AS " + alias.quotedDatabaseIdentifier
            } else {
                return try "(" + query.sql(db, &arguments) + ")"
            }
        }
    }
}


// MARK: - _SQLOrdering

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLOrdering {
    var reversedOrdering: _SQLOrderingExpression { get }
    func orderingSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String
}

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum _SQLOrderingExpression {
    case asc(_SQLExpression)
    case desc(_SQLExpression)
}

extension _SQLOrderingExpression : _SQLOrdering {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var reversedOrdering: _SQLOrderingExpression {
        switch self {
        case .asc(let expression):
            return .desc(expression)
        case .desc(let expression):
            return .asc(expression)
        }
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        switch self {
        case .asc(let expression):
            return try expression.sql(db, &arguments) + " ASC"
        case .desc(let expression):
            return try expression.sql(db, &arguments) + " DESC"
        }
    }
}


// MARK: - _SQLLimit

struct _SQLLimit {
    let limit: Int
    let offset: Int?
    
    var sql: String {
        if let offset = offset {
            return "\(limit) OFFSET \(offset)"
        } else {
            return "\(limit)"
        }
    }
}


// MARK: - _SQLExpressible

public protocol _SQLExpressible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    var sqlExpression: _SQLExpression { get }
}

// Conformance to _SQLExpressible
extension DatabaseValueConvertible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlExpression: _SQLExpression {
        return .value(self)
    }
}

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SpecificSQLExpressible : _SQLExpressible {
    // _SQLExpressible can be adopted by Swift standard types, and user
    // types, through the DatabaseValueConvertible protocol, which inherits
    // from _SQLExpressible.
    //
    // For example, Int adopts _SQLExpressible through
    // DatabaseValueConvertible.
    //
    // _SpecificSQLExpressible, on the other side, is not adopted by any
    // Swift standard type or any user type. It is only adopted by GRDB types,
    // such as SQLColumn and _SQLExpression.
    //
    // This separation lets us define functions and operators that do not
    // spill out. The three declarations below have no chance overloading a
    // Swift-defined operator, or a user-defined operator:
    //
    // - ==(_SQLExpressible, _SpecificSQLExpressible)
    // - ==(_SpecificSQLExpressible, _SQLExpressible)
    // - ==(_SpecificSQLExpressible, _SpecificSQLExpressible)
}

extension _SpecificSQLExpressible where Self: _SQLOrdering {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var reversedOrdering: _SQLOrderingExpression {
        return .desc(sqlExpression)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        return try sqlExpression.sql(db, &arguments)
    }
}

extension _SpecificSQLExpressible where Self: _SQLSelectable {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func resultColumnSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        return try sqlExpression.sql(db, &arguments)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func countedSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        return try sqlExpression.sql(db, &arguments)
    }
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlSelectableKind: _SQLSelectableKind {
        return .expression(sqlExpression)
    }
}

extension _SpecificSQLExpressible {
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: _SQLOrderingExpression {
        return .asc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: _SQLOrderingExpression {
        return .desc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.select()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func aliased(_ alias: String) -> _SQLSelectable {
        return _SQLResultColumn.expression(expression: sqlExpression, alias: alias)
    }
}


/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public indirect enum _SQLExpression {
    /// For example: `name || 'rrr' AS pirateName`
    case SQLLiteral(String, StatementArguments?)
    
    /// For example: `1` or `'foo'`
    case value(DatabaseValueConvertible?)   // TODO: switch to DatabaseValue?
    
    /// For example: `name`, `table.name`
    case identifier(identifier: String, sourceName: String?)
    
    /// For example: `name = 'foo' COLLATE NOCASE`
    case collate(_SQLExpression, String)
    
    /// For example: `NOT condition`
    case notOperator(_SQLExpression)
    
    /// For example: `name = 'foo'`
    case equalOperator(_SQLExpression, _SQLExpression)
    
    /// For example: `name <> 'foo'`
    case notEqualOperator(_SQLExpression, _SQLExpression)
    
    /// For example: `name IS NULL`
    case isOperator(_SQLExpression, _SQLExpression)
    
    /// For example: `name IS NOT NULL`
    case isNotOperator(_SQLExpression, _SQLExpression)
    
    /// For example: `-value`
    case prefixOperator(String, _SQLExpression)
    
    /// For example: `age + 1`
    case infixOperator(String, _SQLExpression, _SQLExpression)
    
    /// For example: `id IN (1,2,3)`
    case inOperator([_SQLExpression], _SQLExpression)
    
    /// For example `id IN (SELECT ...)`
    case inSubQuery(_SQLSelectQuery, _SQLExpression)
    
    /// For example `EXISTS (SELECT ...)`
    case exists(_SQLSelectQuery)
    
    /// For example: `age BETWEEN 1 AND 2`
    case between(value: _SQLExpression, min: _SQLExpression, max: _SQLExpression)
    
    /// For example: `LOWER(name)`
    case function(String, [_SQLExpression])
    
    /// For example: `COUNT(*)`
    case count(_SQLSelectable)
    
    /// For example: `COUNT(DISTINCT name)`
    case countDistinct(_SQLExpression)
    
    ///
    func sql(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        // NOTE: this method *was* slow to compile
        // https://medium.com/swift-programming/speeding-up-slow-swift-build-times-922feeba5780#.s77wmh4h0
        // 10746.4ms	/Users/groue/Documents/git/groue/GRDB.swift/GRDB/FetchRequest/SQLSelectQuery.swift:439:10	func sql(db: Database, _ arguments: inout StatementArguments) throws -> String
        // Fixes are marked with "## Slow Compile Fix (Swift 2.2.x):"
        //
        switch self {
        case .SQLLiteral(let sql, let literalArguments):
            if let literalArguments = literalArguments {
                arguments.values.append(contentsOf: literalArguments.values)
                for (name, value) in literalArguments.namedValues {
                    if arguments.namedValues[name] != nil {
                        throw DatabaseError(code: SQLITE_MISUSE, message: "argument \(String(reflecting: name)) can't be reused")
                    }
                    arguments.namedValues[name] = value
                }
            }
            return sql
            
        case .value(let value):
            guard let value = value else {
                return "NULL"
            }
            arguments.values.append(value)
            return "?"
            
        case .identifier(let identifier, let sourceName):
            if let sourceName = sourceName {
                return sourceName.quotedDatabaseIdentifier + "." + identifier.quotedDatabaseIdentifier
            } else {
                return identifier.quotedDatabaseIdentifier
            }
            
        case .collate(let expression, let collation):
            let sql = try expression.sql(db, &arguments)
            let chars = sql.characters
            if chars.last! == ")" {
                return String(chars.prefix(upTo: chars.index(chars.endIndex, offsetBy: -1))) + " COLLATE " + collation + ")"
            } else {
                return sql + " COLLATE " + collation
            }
            
        case .notOperator(let condition):
            switch condition {
            case .notOperator(let expression):
                return try expression.sql(db, &arguments)
                
            case .inOperator(let expressions, let expression):
                if expressions.isEmpty {
                    return "1"
                } else {
                    // ## Slow Compile Fix (Swift 2.2.x):
                    // TODO: Check if Swift 3 compiler fixes this line's slow compilation time:
                    //return try "(" + expression.sql(db, &arguments) + " NOT IN (" + expressions.map { try $0.sql(db, &arguments) }.joinWithSeparator(", ") + "))"   // Original, Slow To Compile
                    return try "(" + expression.sql(db, &arguments) + " NOT IN (" + (expressions.map { try $0.sql(db, &arguments) } as [String]).joined(separator: ", ") + "))"
                }
                
            case .inSubQuery(let subQuery, let expression):
                return try "(" + expression.sql(db, &arguments) + " NOT IN (" + subQuery.sql(db, &arguments)  + "))"
                
            case .exists(let subQuery):
                return try "(NOT EXISTS (" + subQuery.sql(db, &arguments)  + "))"
                
            case .equalOperator(let lhs, let rhs):
                return try _SQLExpression.notEqualOperator(lhs, rhs).sql(db, &arguments)
                
            case .notEqualOperator(let lhs, let rhs):
                return try _SQLExpression.equalOperator(lhs, rhs).sql(db, &arguments)
                
            case .isOperator(let lhs, let rhs):
                return try _SQLExpression.isNotOperator(lhs, rhs).sql(db, &arguments)
                
            case .isNotOperator(let lhs, let rhs):
                return try _SQLExpression.isOperator(lhs, rhs).sql(db, &arguments)
                
            default:
                return try "(NOT " + condition.sql(db, &arguments) + ")"
            }
            
        case .equalOperator(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .value(let rhs)) where rhs == nil:
                // Swiftism!
                // Turn `filter(a == nil)` into `a IS NULL` since the intention is obviously to check for NULL. `a = NULL` would evaluate to NULL.
                return try "(" + lhs.sql(db, &arguments) + " IS NULL)"
            case (.value(let lhs), let rhs) where lhs == nil:
                // Swiftism!
                return try "(" + rhs.sql(db, &arguments) + " IS NULL)"
            default:
                return try "(" + lhs.sql(db, &arguments) + " = " + rhs.sql(db, &arguments) + ")"
            }
            
        case .notEqualOperator(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .value(let rhs)) where rhs == nil:
                // Swiftism!
                // Turn `filter(a != nil)` into `a IS NOT NULL` since the intention is obviously to check for NULL. `a <> NULL` would evaluate to NULL.
                return try "(" + lhs.sql(db, &arguments) + " IS NOT NULL)"
            case (.value(let lhs), let rhs) where lhs == nil:
                // Swiftism!
                return try "(" + rhs.sql(db, &arguments) + " IS NOT NULL)"
            default:
                return try "(" + lhs.sql(db, &arguments) + " <> " + rhs.sql(db, &arguments) + ")"
            }
            
        case .isOperator(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .value(let rhs)) where rhs == nil:
                return try "(" + lhs.sql(db, &arguments) + " IS NULL)"
            case (.value(let lhs), let rhs) where lhs == nil:
                return try "(" + rhs.sql(db, &arguments) + " IS NULL)"
            default:
                return try "(" + lhs.sql(db, &arguments) + " IS " + rhs.sql(db, &arguments) + ")"
            }
            
        case .isNotOperator(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .value(let rhs)) where rhs == nil:
                return try "(" + lhs.sql(db, &arguments) + " IS NOT NULL)"
            case (.value(let lhs), let rhs) where lhs == nil:
                return try "(" + rhs.sql(db, &arguments) + " IS NOT NULL)"
            default:
                return try "(" + lhs.sql(db, &arguments) + " IS NOT " + rhs.sql(db, &arguments) + ")"
            }
            
        case .prefixOperator(let SQLOperator, let value):
            return try SQLOperator + value.sql(db, &arguments)
            
        case .infixOperator(let SQLOperator, let lhs, let rhs):
            return try "(" + lhs.sql(db, &arguments) + " \(SQLOperator) " + rhs.sql(db, &arguments) + ")"
            
        case .inOperator(let expressions, let expression):
            guard !expressions.isEmpty else {
                return "0"
            }
            // ## Slow Compile Fix (Swift 2.2.x):
            // TODO: Check if Swift 3 compiler fixes this line's slow compilation time:
            //return try "(" + expression.sql(db, &arguments) + " IN (" + expressions.map { try $0.sql(db, &arguments) }.joinWithSeparator(", ")  + "))"  // Original, Slow To Compile
            return try "(" + expression.sql(db, &arguments) + " IN (" + (expressions.map { try $0.sql(db, &arguments) } as [String]).joined(separator: ", ")  + "))"
        
        case .inSubQuery(let subQuery, let expression):
            return try "(" + expression.sql(db, &arguments) + " IN (" + subQuery.sql(db, &arguments)  + "))"
            
        case .exists(let subQuery):
            return try "(EXISTS (" + subQuery.sql(db, &arguments)  + "))"
            
        case .between(value: let value, min: let min, max: let max):
            return try "(" + value.sql(db, &arguments) + " BETWEEN " + min.sql(db, &arguments) + " AND " + max.sql(db, &arguments) + ")"
            
        case .function(let functionName, let functionArguments):
            // ## Slow Compile Fix (Swift 2.2.x):
            // TODO: Check if Swift 3 compiler fixes this line's slow compilation time:
            //return try functionName + "(" + functionArguments.map { try $0.sql(db, &arguments) }.joinWithSeparator(", ")  + ")"    // Original, Slow To Compile
            return try functionName + "(" + (functionArguments.map { try $0.sql(db, &arguments) } as [String]).joined(separator: ", ")  + ")"
            
        case .count(let counted):
            return try "COUNT(" + counted.countedSQL(db, &arguments) + ")"
            
        case .countDistinct(let expression):
            return try "COUNT(DISTINCT " + expression.sql(db, &arguments) + ")"
        }
    }
}

extension _SQLExpression : _SpecificSQLExpressible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlExpression: _SQLExpression {
        return self
    }
}

extension _SQLExpression : _SQLSelectable {}
extension _SQLExpression : _SQLOrdering {}


// MARK: - _SQLSelectable

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLSelectable {
    func resultColumnSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String
    func countedSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String
    var sqlSelectableKind: _SQLSelectableKind { get }
}

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum _SQLSelectableKind {
    case expression(_SQLExpression)
    case star(sourceName: String?)
}

enum _SQLResultColumn {
    case star(String?)
    case expression(expression: _SQLExpression, alias: String)
}

extension _SQLResultColumn : _SQLSelectable {
    
    func resultColumnSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        switch self {
        case .star(let sourceName):
            if let sourceName = sourceName {
                return sourceName.quotedDatabaseIdentifier + ".*"
            } else {
                return "*"
            }
        case .expression(expression: let expression, alias: let alias):
            return try expression.sql(db, &arguments) + " AS " + alias.quotedDatabaseIdentifier
        }
    }
    
    func countedSQL(_ db: Database, _ arguments: inout StatementArguments) throws -> String {
        switch self {
        case .star:
            return "*"
        case .expression(expression: let expression, alias: _):
            return try expression.sql(db, &arguments)
        }
    }
    
    var sqlSelectableKind: _SQLSelectableKind {
        switch self {
        case .star(let sourceName):
            return .star(sourceName: sourceName)
        case .expression(expression: let expression, alias: _):
            return .expression(expression)
        }
    }
}


// MARK: - SQLColumn

/// A column in the database
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct SQLColumn {
    let sourceName: String?
    
    /// The name of the column
    public let name: String
    
    /// Initializes a column given its name.
    public init(_ name: String) {
        self.name = name
        self.sourceName = nil
    }
    
    init(_ name: String, sourceName: String?) {
        self.name = name
        self.sourceName = sourceName
    }
}

extension SQLColumn : _SpecificSQLExpressible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlExpression: _SQLExpression {
        return .identifier(identifier: name, sourceName: sourceName)
    }
}

extension SQLColumn : _SQLSelectable {}
extension SQLColumn : _SQLOrdering {}
