

// MARK: - _SQLSelectQuery

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public struct _SQLSelectQuery {
    var selection: [_SQLSelectable]
    var distinct: Bool
    var source: _SQLSource?
    var whereExpression: _SQLExpression?
    var groupByExpressions: [_SQLExpression]
    var orderings: [_SQLOrdering]
    var reversed: Bool
    var havingExpression: _SQLExpression?
    var limit: _SQLLimit?
    
    init(
        select selection: [_SQLSelectable],
        distinct: Bool = false,
        from source: _SQLSource? = nil,
        filter whereExpression: _SQLExpression? = nil,
        groupBy groupByExpressions: [_SQLExpression] = [],
        orderBy orderings: [_SQLOrdering] = [],
        reversed: Bool = false,
        having havingExpression: _SQLExpression? = nil,
        limit: _SQLLimit? = nil)
    {
        self.selection = selection
        self.distinct = distinct
        self.source = source
        self.whereExpression = whereExpression
        self.groupByExpressions = groupByExpressions
        self.orderings = orderings
        self.reversed = reversed
        self.havingExpression = havingExpression
        self.limit = limit
    }
    
    func sql(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        var sql = "SELECT"
        
        if distinct {
            sql += " DISTINCT"
        }
        
        assert(!selection.isEmpty)
        sql += try " " + selection.map { try $0.resultColumnSQL(db, &bindings) }.joinWithSeparator(", ")
        
        if let source = source {
            sql += try " FROM " + source.sql(db, &bindings)
        }
        
        if let whereExpression = whereExpression {
            sql += try " WHERE " + whereExpression.sql(db, &bindings)
        }
        
        if !groupByExpressions.isEmpty {
            sql += try " GROUP BY " + groupByExpressions.map { try $0.sql(db, &bindings) }.joinWithSeparator(", ")
        }
        
        if let havingExpression = havingExpression {
            sql += try " HAVING " + havingExpression.sql(db, &bindings)
        }
        
        var orderings = self.orderings
        if reversed {
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
                orderings = orderings.map { $0.reversedSortDescriptor }
            }
        }
        if !orderings.isEmpty {
            sql += try " ORDER BY " + orderings.map { try $0.orderingSQL(db, &bindings) }.joinWithSeparator(", ")
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
        
        guard let source = source, case .Table(name: let tableName, alias: let alias) = source else {
            // SELECT ... FROM (something which is not a table)
            return trivialCountQuery
        }
        
        assert(!selection.isEmpty)
        if selection.count == 1 {
            let selectable = self.selection[0]
            switch selectable.sqlSelectableKind {
            case .Star(sourceName: let sourceName):
                guard !distinct else {
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
                countQuery.selection = [_SQLExpression.Count(selectable)]
                return countQuery
                
            case .Expression(let expression):
                // SELECT [DISTINCT] expr FROM tableName ...
                if distinct {
                    // SELECT DISTINCT expr FROM tableName ...
                    // ->
                    // SELECT COUNT(DISTINCT expr) FROM tableName ...
                    var countQuery = unorderedQuery
                    countQuery.distinct = false
                    countQuery.selection = [_SQLExpression.CountDistinct(expression)]
                    return countQuery
                } else {
                    // SELECT expr FROM tableName ...
                    // ->
                    // SELECT COUNT(*) FROM tableName ...
                    var countQuery = unorderedQuery
                    countQuery.selection = [_SQLExpression.Count(_SQLResultColumn.Star(nil))]
                    return countQuery
                }
            }
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
            
            guard !distinct else {
                return trivialCountQuery
            }

            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            var countQuery = unorderedQuery
            countQuery.selection = [_SQLExpression.Count(_SQLResultColumn.Star(nil))]
            return countQuery
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    private var trivialCountQuery: _SQLSelectQuery {
        return _SQLSelectQuery(
            select: [_SQLExpression.Count(_SQLResultColumn.Star(nil))],
            from: .Query(query: unorderedQuery, alias: nil))
    }
    
    /// Remove ordering
    private var unorderedQuery: _SQLSelectQuery {
        var query = self
        query.reversed = false
        query.orderings = []
        return query
    }
}


// MARK: - _SQLSource

indirect enum _SQLSource {
    case Table(name: String, alias: String?)
    case Query(query: _SQLSelectQuery, alias: String?)
    
    func sql(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        switch self {
        case .Table(let table, let alias):
            if let alias = alias {
                return table.quotedDatabaseIdentifier + " AS " + alias.quotedDatabaseIdentifier
            } else {
                return table.quotedDatabaseIdentifier
            }
        case .Query(let query, let alias):
            if let alias = alias {
                return try "(" + query.sql(db, &bindings) + ") AS " + alias.quotedDatabaseIdentifier
            } else {
                return try "(" + query.sql(db, &bindings) + ")"
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
    var reversedSortDescriptor: _SQLSortDescriptor { get }
    func orderingSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
}

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum _SQLSortDescriptor {
    case Asc(_SQLExpression)
    case Desc(_SQLExpression)
}

extension _SQLSortDescriptor : _SQLOrdering {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var reversedSortDescriptor: _SQLSortDescriptor {
        switch self {
        case .Asc(let expression):
            return .Desc(expression)
        case .Desc(let expression):
            return .Asc(expression)
        }
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        switch self {
        case .Asc(let expression):
            return try expression.sql(db, &bindings) + " ASC"
        case .Desc(let expression):
            return try expression.sql(db, &bindings) + " DESC"
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
        return .Value(self)
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
    // such as SQLColumn, _SQLExpression and _SQLLiteral.
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
    public var reversedSortDescriptor: _SQLSortDescriptor {
        return .Desc(sqlExpression)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        return try sqlExpression.sql(db, &bindings)
    }
}

extension _SpecificSQLExpressible where Self: _SQLSelectable {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func resultColumnSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        return try sqlExpression.sql(db, &bindings)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func countedSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        return try sqlExpression.sql(db, &bindings)
    }
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlSelectableKind: _SQLSelectableKind {
        return .Expression(sqlExpression)
    }
}

extension _SpecificSQLExpressible {
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: _SQLSortDescriptor {
        return .Asc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: _SQLSortDescriptor {
        return .Desc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.select()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func aliased(alias: String) -> _SQLSelectable {
        return _SQLResultColumn.Expression(expression: sqlExpression, alias: alias)
    }
}


/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public indirect enum _SQLExpression {
    /// For example: `name || 'rrr' AS pirateName`
    case Literal(String)
    
    /// For example: `1` or `'foo'`
    case Value(DatabaseValueConvertible?)   // TODO: switch to DatabaseValue?
    
    /// For example: `name`, `table.name`
    case Identifier(identifier: String, sourceName: String?)
    
    /// For example: `name = 'foo' COLLATE NOCASE`
    case Collate(_SQLExpression, String)
    
    /// For example: `NOT condition`
    case Not(_SQLExpression)
    
    /// For example: `name = 'foo'`
    case Equal(_SQLExpression, _SQLExpression)
    
    /// For example: `name <> 'foo'`
    case NotEqual(_SQLExpression, _SQLExpression)
    
    /// For example: `name IS NULL`
    case Is(_SQLExpression, _SQLExpression)
    
    /// For example: `name IS NOT NULL`
    case IsNot(_SQLExpression, _SQLExpression)
    
    /// For example: `-value`
    case PrefixOperator(String, _SQLExpression)
    
    /// For example: `age + 1`
    case InfixOperator(String, _SQLExpression, _SQLExpression)
    
    /// For example: `id IN (1,2,3)`
    case In([_SQLExpression], _SQLExpression)
    
    /// For example `id IN (SELECT ...)`
    case InSubQuery(_SQLSelectQuery, _SQLExpression)
    
    /// For example `EXISTS (SELECT ...)`
    case Exists(_SQLSelectQuery)
    
    /// For example: `age BETWEEN 1 AND 2`
    case Between(value: _SQLExpression, min: _SQLExpression, max: _SQLExpression)
    
    /// For example: `LOWER(name)`
    case Function(String, [_SQLExpression])
    
    /// For example: `COUNT(*)`
    case Count(_SQLSelectable)
    
    /// For example: `COUNT(DISTINCT name)`
    case CountDistinct(_SQLExpression)
    
    ///
    func sql(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        // NOTE: this method *was* slow to compile
        // https://medium.com/swift-programming/speeding-up-slow-swift-build-times-922feeba5780#.s77wmh4h0
        // 10746.4ms	/Users/groue/Documents/git/groue/GRDB.swift/GRDB/FetchRequest/SQLSelectQuery.swift:439:10	func sql(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
        // Fixes are marked with "## Slow Compile Fix (Swift 2.2.x):"
        //
        switch self {
        case .Literal(let sql):
            return sql
            
        case .Value(let value):
            guard let value = value else {
                return "NULL"
            }
            bindings.append(value)
            return "?"
            
        case .Identifier(let identifier, let sourceName):
            if let sourceName = sourceName {
                return sourceName.quotedDatabaseIdentifier + "." + identifier.quotedDatabaseIdentifier
            } else {
                return identifier.quotedDatabaseIdentifier
            }
            
        case .Collate(let expression, let collation):
            let sql = try expression.sql(db, &bindings)
            let chars = sql.characters
            if chars.last! == ")" {
                return String(chars.prefixUpTo(chars.endIndex.predecessor())) + " COLLATE " + collation + ")"
            } else {
                return sql + " COLLATE " + collation
            }
            
        case .Not(let condition):
            switch condition {
            case .Not(let expression):
                return try expression.sql(db, &bindings)
                
            case .In(let expressions, let expression):
                if expressions.isEmpty {
                    return "1"
                } else {
                    // ## Slow Compile Fix (Swift 2.2.x):
                    // TODO: Check if Swift 3 compiler fixes this line's slow compilation time:
                    //return try "(" + expression.sql(db, &bindings) + " NOT IN (" + expressions.map { try $0.sql(db, &bindings) }.joinWithSeparator(", ") + "))"   // Original, Slow To Compile
                    return try "(" + expression.sql(db, &bindings) + " NOT IN (" + (expressions.map { try $0.sql(db, &bindings) } as [String]).joinWithSeparator(", ") + "))"
                }
                
            case .InSubQuery(let subQuery, let expression):
                return try "(" + expression.sql(db, &bindings) + " NOT IN (" + subQuery.sql(db, &bindings)  + "))"
                
            case .Exists(let subQuery):
                return try "(NOT EXISTS (" + subQuery.sql(db, &bindings)  + "))"
                
            case .Equal(let lhs, let rhs):
                return try _SQLExpression.NotEqual(lhs, rhs).sql(db, &bindings)
                
            case .NotEqual(let lhs, let rhs):
                return try _SQLExpression.Equal(lhs, rhs).sql(db, &bindings)
                
            case .Is(let lhs, let rhs):
                return try _SQLExpression.IsNot(lhs, rhs).sql(db, &bindings)
                
            case .IsNot(let lhs, let rhs):
                return try _SQLExpression.Is(lhs, rhs).sql(db, &bindings)
                
            default:
                return try "(NOT " + condition.sql(db, &bindings) + ")"
            }
            
        case .Equal(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs == nil:
                // Swiftism!
                // Turn `filter(a == nil)` into `a IS NULL` since the intention is obviously to check for NULL. `a = NULL` would evaluate to NULL.
                return try "(" + lhs.sql(db, &bindings) + " IS NULL)"
            case (.Value(let lhs), let rhs) where lhs == nil:
                // Swiftism!
                return try "(" + rhs.sql(db, &bindings) + " IS NULL)"
            default:
                return try "(" + lhs.sql(db, &bindings) + " = " + rhs.sql(db, &bindings) + ")"
            }
            
        case .NotEqual(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs == nil:
                // Swiftism!
                // Turn `filter(a != nil)` into `a IS NOT NULL` since the intention is obviously to check for NULL. `a <> NULL` would evaluate to NULL.
                return try "(" + lhs.sql(db, &bindings) + " IS NOT NULL)"
            case (.Value(let lhs), let rhs) where lhs == nil:
                // Swiftism!
                return try "(" + rhs.sql(db, &bindings) + " IS NOT NULL)"
            default:
                return try "(" + lhs.sql(db, &bindings) + " <> " + rhs.sql(db, &bindings) + ")"
            }
            
        case .Is(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs == nil:
                return try "(" + lhs.sql(db, &bindings) + " IS NULL)"
            case (.Value(let lhs), let rhs) where lhs == nil:
                return try "(" + rhs.sql(db, &bindings) + " IS NULL)"
            default:
                return try "(" + lhs.sql(db, &bindings) + " IS " + rhs.sql(db, &bindings) + ")"
            }
            
        case .IsNot(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs == nil:
                return try "(" + lhs.sql(db, &bindings) + " IS NOT NULL)"
            case (.Value(let lhs), let rhs) where lhs == nil:
                return try "(" + rhs.sql(db, &bindings) + " IS NOT NULL)"
            default:
                return try "(" + lhs.sql(db, &bindings) + " IS NOT " + rhs.sql(db, &bindings) + ")"
            }
            
        case .PrefixOperator(let SQLOperator, let value):
            return try SQLOperator + value.sql(db, &bindings)
            
        case .InfixOperator(let SQLOperator, let lhs, let rhs):
            return try "(" + lhs.sql(db, &bindings) + " \(SQLOperator) " + rhs.sql(db, &bindings) + ")"
            
        case .In(let expressions, let expression):
            guard !expressions.isEmpty else {
                return "0"
            }
            // ## Slow Compile Fix (Swift 2.2.x):
            // TODO: Check if Swift 3 compiler fixes this line's slow compilation time:
            //return try "(" + expression.sql(db, &bindings) + " IN (" + expressions.map { try $0.sql(db, &bindings) }.joinWithSeparator(", ")  + "))"  // Original, Slow To Compile
            return try "(" + expression.sql(db, &bindings) + " IN (" + (expressions.map { try $0.sql(db, &bindings) } as [String]).joinWithSeparator(", ")  + "))"
        
        case .InSubQuery(let subQuery, let expression):
            return try "(" + expression.sql(db, &bindings) + " IN (" + subQuery.sql(db, &bindings)  + "))"
            
        case .Exists(let subQuery):
            return try "(EXISTS (" + subQuery.sql(db, &bindings)  + "))"
            
        case .Between(value: let value, min: let min, max: let max):
            return try "(" + value.sql(db, &bindings) + " BETWEEN " + min.sql(db, &bindings) + " AND " + max.sql(db, &bindings) + ")"
            
        case .Function(let functionName, let functionArguments):
            // ## Slow Compile Fix (Swift 2.2.x):
            // TODO: Check if Swift 3 compiler fixes this line's slow compilation time:
            //return try functionName + "(" + functionArguments.map { try $0.sql(db, &bindings) }.joinWithSeparator(", ")  + ")"    // Original, Slow To Compile
            return try functionName + "(" + (functionArguments.map { try $0.sql(db, &bindings) } as [String]).joinWithSeparator(", ")  + ")"
            
        case .Count(let counted):
            return try "COUNT(" + counted.countedSQL(db, &bindings) + ")"
            
        case .CountDistinct(let expression):
            return try "COUNT(DISTINCT " + expression.sql(db, &bindings) + ")"
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
    func resultColumnSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
    func countedSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String
    var sqlSelectableKind: _SQLSelectableKind { get }
}

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum _SQLSelectableKind {
    case Expression(_SQLExpression)
    case Star(sourceName: String?)
}

enum _SQLResultColumn {
    case Star(String?)
    case Expression(expression: _SQLExpression, alias: String)
}

extension _SQLResultColumn : _SQLSelectable {
    
    func resultColumnSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        switch self {
        case .Star(let sourceName):
            if let sourceName = sourceName {
                return sourceName.quotedDatabaseIdentifier + ".*"
            } else {
                return "*"
            }
        case .Expression(expression: let expression, alias: let alias):
            return try expression.sql(db, &bindings) + " AS " + alias.quotedDatabaseIdentifier
        }
    }
    
    func countedSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        switch self {
        case .Star:
            return "*"
        case .Expression(expression: let expression, alias: _):
            return try expression.sql(db, &bindings)
        }
    }
    
    var sqlSelectableKind: _SQLSelectableKind {
        switch self {
        case .Star(let sourceName):
            return .Star(sourceName: sourceName)
        case .Expression(expression: let expression, alias: _):
            return .Expression(expression)
        }
    }
}


// MARK: _SQLLiteral

struct _SQLLiteral {
    let sql: String
    init(_ sql: String) {
        self.sql = sql
    }
}

extension _SQLLiteral : _SpecificSQLExpressible {
    var sqlExpression: _SQLExpression {
        return .Literal(sql)
    }
}

extension _SQLLiteral : _SQLSelectable {}
extension _SQLLiteral : _SQLOrdering {}


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
        return .Identifier(identifier: name, sourceName: sourceName)
    }
}

extension SQLColumn : _SQLSelectable {}
extension SQLColumn : _SQLOrdering {}
