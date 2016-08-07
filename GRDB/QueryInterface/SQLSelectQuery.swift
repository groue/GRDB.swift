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
    var orderings: [_SQLOrderable]
    var isReversed: Bool
    var havingExpression: _SQLExpression?
    var limit: _SQLLimit?
    
    init(
        select selection: [_SQLSelectable],
        isDistinct: Bool = false,
        from source: _SQLSource? = nil,
        filter whereExpression: _SQLExpression? = nil,
        groupBy groupByExpressions: [_SQLExpression] = [],
        orderBy orderings: [_SQLOrderable] = [],
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
    
    func sql(_ arguments: inout StatementArguments?) -> String {
        var sql = "SELECT"
        
        if isDistinct {
            sql += " DISTINCT"
        }
        
        assert(!selection.isEmpty)
        sql += " " + selection.map { $0.resultColumnSQL(&arguments) }.joined(separator: ", ")
        
        if let source = source {
            sql += " FROM " + source.sql(&arguments)
        }
        
        if let whereExpression = whereExpression {
            sql += " WHERE " + whereExpression.sql(&arguments)
        }
        
        if !groupByExpressions.isEmpty {
            sql += " GROUP BY " + groupByExpressions.map { $0.sql(&arguments) }.joined(separator: ", ")
        }
        
        if let havingExpression = havingExpression {
            sql += " HAVING " + havingExpression.sql(&arguments)
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
                orderings = [Column("_rowid_").desc]
            } else {
                orderings = orderings.map { $0.reversedOrdering }
            }
        }
        if !orderings.isEmpty {
            sql += " ORDER BY " + orderings.map { $0.orderingSQL(&arguments) }.joined(separator: ", ")
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
    
    func sql(_ arguments: inout StatementArguments?) -> String {
        switch self {
        case .table(let table, let alias):
            if let alias = alias {
                return table.quotedDatabaseIdentifier + " AS " + alias.quotedDatabaseIdentifier
            } else {
                return table.quotedDatabaseIdentifier
            }
        case .query(let query, let alias):
            if let alias = alias {
                return "(" + query.sql(&arguments) + ") AS " + alias.quotedDatabaseIdentifier
            } else {
                return "(" + query.sql(&arguments) + ")"
            }
        }
    }
}


// MARK: - _SQLOrderable

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLOrderable {
    var reversedOrdering: _SQLOrderingExpression { get }
    func orderingSQL(_ arguments: inout StatementArguments?) -> String
}

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum _SQLOrderingExpression {
    case asc(_SQLExpression)
    case desc(_SQLExpression)
}

extension _SQLOrderingExpression : _SQLOrderable {
    
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
    public func orderingSQL(_ arguments: inout StatementArguments?) -> String {
        switch self {
        case .asc(let expression):
            return expression.sql(&arguments) + " ASC"
        case .desc(let expression):
            return expression.sql(&arguments) + " DESC"
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


// MARK: - _SpecificSQLExpressible

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SpecificSQLExpressible : SQLExpressible {
    // SQLExpressible can be adopted by Swift standard types, and user
    // types, through the DatabaseValueConvertible protocol which inherits
    // from SQLExpressible.
    //
    // For example, Int adopts SQLExpressible through
    // DatabaseValueConvertible.
    //
    // _SpecificSQLExpressible, on the other side, is not adopted by any
    // Swift standard type or any user type. It is only adopted by GRDB types,
    // such as Column and _SQLExpression.
    //
    // This separation lets us define functions and operators that do not
    // spill out. The three declarations below have no chance overloading a
    // Swift-defined operator, or a user-defined operator:
    //
    // - ==(SQLExpressible, _SpecificSQLExpressible)
    // - ==(_SpecificSQLExpressible, SQLExpressible)
    // - ==(_SpecificSQLExpressible, _SpecificSQLExpressible)
}

extension _SpecificSQLExpressible where Self: _SQLOrderable {
    
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
    public func orderingSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.sql(&arguments)
    }
}

extension _SpecificSQLExpressible where Self: _SQLSelectable {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.sql(&arguments)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.sql(&arguments)
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
    case sqlLiteral(String, StatementArguments?)
    
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
    func sql(_ arguments: inout StatementArguments?) -> String {
        switch self {
        case .sqlLiteral(let sql, let literalArguments):
            if let literalArguments = literalArguments {
                guard arguments != nil else {
                    fatalError("Not implemented")
                }
                arguments!.values.append(contentsOf: literalArguments.values)
                for (name, value) in literalArguments.namedValues {
                    guard arguments!.namedValues[name] == nil else {
                        fatalError("argument \(String(reflecting: name)) can't be reused")
                    }
                    arguments!.namedValues[name] = value
                }
            }
            return sql
            
        case .value(let value):
            guard let value = value else {
                return "NULL"
            }
            if arguments == nil {
                return value.sqlLiteral
            } else {
                arguments!.values.append(value)
                return "?"
            }
            
        case .identifier(let identifier, let sourceName):
            if let sourceName = sourceName {
                return sourceName.quotedDatabaseIdentifier + "." + identifier.quotedDatabaseIdentifier
            } else {
                return identifier.quotedDatabaseIdentifier
            }
            
        case .collate(let expression, let collation):
            let sql = expression.sql(&arguments)
            let chars = sql.characters
            if chars.last! == ")" {
                return String(chars.prefix(upTo: chars.index(chars.endIndex, offsetBy: -1))) + " COLLATE " + collation + ")"
            } else {
                return sql + " COLLATE " + collation
            }
            
        case .notOperator(let condition):
            switch condition {
            case .notOperator(let expression):
                return expression.sql(&arguments)
                
            case .inOperator(let expressions, let expression):
                if expressions.isEmpty {
                    return "1"
                } else {
                    return "(" + expression.sql(&arguments) + " NOT IN (" + (expressions.map { $0.sql(&arguments) } as [String]).joined(separator: ", ") + "))"
                }
                
            case .inSubQuery(let subQuery, let expression):
                return "(" + expression.sql(&arguments) + " NOT IN (" + subQuery.sql(&arguments)  + "))"
                
            case .exists(let subQuery):
                return "(NOT EXISTS (" + subQuery.sql(&arguments)  + "))"
                
            case .equalOperator(let lhs, let rhs):
                return _SQLExpression.notEqualOperator(lhs, rhs).sql(&arguments)
                
            case .notEqualOperator(let lhs, let rhs):
                return _SQLExpression.equalOperator(lhs, rhs).sql(&arguments)
                
            case .isOperator(let lhs, let rhs):
                return _SQLExpression.isNotOperator(lhs, rhs).sql(&arguments)
                
            case .isNotOperator(let lhs, let rhs):
                return _SQLExpression.isOperator(lhs, rhs).sql(&arguments)
                
            default:
                return "(NOT " + condition.sql(&arguments) + ")"
            }
            
        case .equalOperator(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .value(let rhs)) where rhs == nil:
                // Swiftism!
                // Turn `filter(a == nil)` into `a IS NULL` since the intention is obviously to check for NULL. `a = NULL` would evaluate to NULL.
                return "(" + lhs.sql(&arguments) + " IS NULL)"
            case (.value(let lhs), let rhs) where lhs == nil:
                // Swiftism!
                return "(" + rhs.sql(&arguments) + " IS NULL)"
            default:
                return "(" + lhs.sql(&arguments) + " = " + rhs.sql(&arguments) + ")"
            }
            
        case .notEqualOperator(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .value(let rhs)) where rhs == nil:
                // Swiftism!
                // Turn `filter(a != nil)` into `a IS NOT NULL` since the intention is obviously to check for NULL. `a <> NULL` would evaluate to NULL.
                return "(" + lhs.sql(&arguments) + " IS NOT NULL)"
            case (.value(let lhs), let rhs) where lhs == nil:
                // Swiftism!
                return "(" + rhs.sql(&arguments) + " IS NOT NULL)"
            default:
                return "(" + lhs.sql(&arguments) + " <> " + rhs.sql(&arguments) + ")"
            }
            
        case .isOperator(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .value(let rhs)) where rhs == nil:
                return "(" + lhs.sql(&arguments) + " IS NULL)"
            case (.value(let lhs), let rhs) where lhs == nil:
                return "(" + rhs.sql(&arguments) + " IS NULL)"
            default:
                return "(" + lhs.sql(&arguments) + " IS " + rhs.sql(&arguments) + ")"
            }
            
        case .isNotOperator(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .value(let rhs)) where rhs == nil:
                return "(" + lhs.sql(&arguments) + " IS NOT NULL)"
            case (.value(let lhs), let rhs) where lhs == nil:
                return "(" + rhs.sql(&arguments) + " IS NOT NULL)"
            default:
                return "(" + lhs.sql(&arguments) + " IS NOT " + rhs.sql(&arguments) + ")"
            }
            
        case .prefixOperator(let SQLOperator, let value):
            return SQLOperator + value.sql(&arguments)
            
        case .infixOperator(let SQLOperator, let lhs, let rhs):
            return "(" + lhs.sql(&arguments) + " \(SQLOperator) " + rhs.sql(&arguments) + ")"
            
        case .inOperator(let expressions, let expression):
            guard !expressions.isEmpty else {
                return "0"
            }
            return "(" + expression.sql(&arguments) + " IN (" + (expressions.map { $0.sql(&arguments) } as [String]).joined(separator: ", ")  + "))"
        
        case .inSubQuery(let subQuery, let expression):
            return "(" + expression.sql(&arguments) + " IN (" + subQuery.sql(&arguments)  + "))"
            
        case .exists(let subQuery):
            return "(EXISTS (" + subQuery.sql(&arguments)  + "))"
            
        case .between(value: let value, min: let min, max: let max):
            return "(" + value.sql(&arguments) + " BETWEEN " + min.sql(&arguments) + " AND " + max.sql(&arguments) + ")"
            
        case .function(let functionName, let functionArguments):
            return functionName + "(" + (functionArguments.map { $0.sql(&arguments) } as [String]).joined(separator: ", ")  + ")"
            
        case .count(let counted):
            return "COUNT(" + counted.countedSQL(&arguments) + ")"
            
        case .countDistinct(let expression):
            return "COUNT(DISTINCT " + expression.sql(&arguments) + ")"
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
extension _SQLExpression : _SQLOrderable {}


// MARK: - _SQLSelectable

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLSelectable {
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String
    func countedSQL(_ arguments: inout StatementArguments?) -> String
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
    
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        switch self {
        case .star(let sourceName):
            if let sourceName = sourceName {
                return sourceName.quotedDatabaseIdentifier + ".*"
            } else {
                return "*"
            }
        case .expression(expression: let expression, alias: let alias):
            return expression.sql(&arguments) + " AS " + alias.quotedDatabaseIdentifier
        }
    }
    
    func countedSQL(_ arguments: inout StatementArguments?) -> String {
        switch self {
        case .star:
            return "*"
        case .expression(expression: let expression, alias: _):
            return expression.sql(&arguments)
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


// MARK: - Column

/// A column in the database
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct Column {
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

extension Column : _SpecificSQLExpressible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlExpression: _SQLExpression {
        return .identifier(identifier: name, sourceName: sourceName)
    }
}

extension Column : _SQLSelectable {}
extension Column : _SQLOrderable {}
