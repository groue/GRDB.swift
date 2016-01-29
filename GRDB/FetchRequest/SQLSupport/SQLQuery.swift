

// MARK: - _SQLQuery

struct _SQLQuery {
    var selection: [_SQLSelectable]
    var distinct: Bool
    var source: _SQLSource?
    var whereExpression: _SQLExpression?
    var groupByExpressions: [_SQLExpression]
    var sortDescriptors: [_SQLSortDescriptorType]
    var reversed: Bool
    var havingExpression: _SQLExpression?
    var limit: _SQLLimit?
    
    init(
        select selection: [_SQLSelectable],
        distinct: Bool = false,
        from source: _SQLSource? = nil,
        filter whereExpression: _SQLExpression? = nil,
        groupBy groupByExpressions: [_SQLExpression] = [],
        orderBy sortDescriptors: [_SQLSortDescriptorType] = [],
        reversed: Bool = false,
        having havingExpression: _SQLExpression? = nil,
        limit: _SQLLimit? = nil)
    {
        self.selection = selection
        self.distinct = distinct
        self.source = source
        self.whereExpression = whereExpression
        self.groupByExpressions = groupByExpressions
        self.sortDescriptors = sortDescriptors
        self.reversed = reversed
        self.havingExpression = havingExpression
        self.limit = limit
    }
    
    func sql(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        var sql = "SELECT"
        
        if distinct {
            sql += " DISTINCT"
        }
        
        sql += try " " + selection.map { try $0.resultColumnSQL(&bindings) }.joinWithSeparator(", ")
        
        if let source = source {
            sql += try " FROM " + source.sql(db, &bindings)
        }
        
        if let whereExpression = whereExpression {
            sql += try " WHERE " + whereExpression.sql(&bindings)
        }
        
        if !groupByExpressions.isEmpty {
            sql += try " GROUP BY " + groupByExpressions.map { try $0.sql(&bindings) }.joinWithSeparator(", ")
        }
        
        if let havingExpression = havingExpression {
            sql += try " HAVING " + havingExpression.sql(&bindings)
        }
        
        var sortDescriptors = self.sortDescriptors
        if reversed {
            if sortDescriptors.isEmpty {
                guard let source = source, case .Table(let tableName, let alias) = source else {
                    throw DatabaseError(message: "can't reverse without a source table")
                }
                guard case let columns = try db.primaryKey(tableName).columns where !columns.isEmpty else {
                    throw DatabaseError(message: "can't reverse a table without primary key")
                }
                sortDescriptors = columns.map { _SQLSortDescriptor.Desc(_SQLExpression.Identifier(identifier: $0, sourceName: alias)) }
            } else {
                sortDescriptors = sortDescriptors.map { $0.reversedSortDescriptor }
            }
        }
        if !sortDescriptors.isEmpty {
            sql += try " ORDER BY " + sortDescriptors.map { try $0.orderingSQL(&bindings) }.joinWithSeparator(", ")
        }
        
        if let limit = limit {
            sql += " LIMIT " + limit.sql
        }
        
        return sql
    }
}


// MARK: - _SQLQuery derivation

extension _SQLQuery {
    
    @warn_unused_result
    func select(selection: [_SQLSelectable]) -> _SQLQuery {
        var query = self
        query.selection = selection
        return query
    }
    
    @warn_unused_result
    func filter(predicate: _SQLExpression) -> _SQLQuery {
        var query = self
        if let whereExpression = query.whereExpression {
            query.whereExpression = .InfixOperator("AND", whereExpression, predicate)
        } else {
            query.whereExpression = predicate
        }
        return query
    }
    
    @warn_unused_result
    func group(expressions: [_SQLExpression]) -> _SQLQuery {
        var query = self
        query.groupByExpressions = expressions
        return query
    }
    
    @warn_unused_result
    func having(predicate: _SQLExpression) -> _SQLQuery {
        var query = self
        if let havingExpression = query.havingExpression {
            query.havingExpression = .InfixOperator("AND", havingExpression, predicate)
        } else {
            query.havingExpression = predicate
        }
        return query
    }
    
    @warn_unused_result
    func order(sortDescriptors: [_SQLSortDescriptorType]) -> _SQLQuery {
        var query = self
        query.sortDescriptors.appendContentsOf(sortDescriptors)
        return query
    }
    
    @warn_unused_result
    func limit(limit: Int, offset: Int?) -> _SQLQuery {
        var query = self
        query.limit = _SQLLimit(limit: limit, offset: offset)
        return query
    }
}


// MARK: - _SQLSource

indirect enum _SQLSource {
    case Table(name: String, alias: String?)
    case Query(_SQLQuery, alias: String)
    case Join(_SQLSource, _SQLExpression, _SQLSource)
    
    // a JOIN b ON ab JOIN c ON abc
    // ((a,b,ab), c, abc)
    func sql(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        switch self {
        case .Table(let table, let alias):
            if let alias = alias {
                return table.quotedDatabaseIdentifier + " AS " + alias.quotedDatabaseIdentifier
            } else {
                return table.quotedDatabaseIdentifier
            }
        case .Query(let query, let alias):
            return try "(" + query.sql(db, &bindings) + ") AS " + alias.quotedDatabaseIdentifier
        case .Join(let first, let expression, let second):
            switch second {
            case .Join:
                fatalError("WTF")
            default:
                break
            }
            return try first.sql(db, &bindings) + " JOIN " + second.sql(db, &bindings) + " ON " + expression.sql(&bindings)
        }
    }
}


// MARK: - _SQLSortDescriptorType

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLSortDescriptorType {
    var reversedSortDescriptor: _SQLSortDescriptor { get }
    func orderingSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String
}

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum _SQLSortDescriptor {
    case Asc(_SQLExpression)
    case Desc(_SQLExpression)
}

extension _SQLSortDescriptor : _SQLSortDescriptorType {
    
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
    public func orderingSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String {
        switch self {
        case .Asc(let expression):
            return try expression.sql(&bindings) + " ASC"
        case .Desc(let expression):
            return try expression.sql(&bindings) + " DESC"
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


// MARK: - _SQLExpressionType

public protocol _SQLExpressionType {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    var SQLExpression: _SQLExpression { get }
}

// Conformance to _SQLExpressionType
extension DatabaseValueConvertible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var SQLExpression: _SQLExpression {
        return .Value(self)
    }
}

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _DerivedSQLExpressionType : _SQLExpressionType, _SQLSortDescriptorType, _SQLSelectable {
}

// Conformance to _SQLSortDescriptorType
extension _DerivedSQLExpressionType {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var reversedSortDescriptor: _SQLSortDescriptor {
        return .Desc(SQLExpression)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String {
        return try SQLExpression.sql(&bindings)
    }
}

// Conformance to _SQLSelectable
extension _DerivedSQLExpressionType {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func resultColumnSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String {
        return try SQLExpression.sql(&bindings)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func countedSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String {
        return try SQLExpression.sql(&bindings)
    }
}

extension _DerivedSQLExpressionType {
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: _SQLSortDescriptorType {
        return _SQLSortDescriptor.Asc(SQLExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: _SQLSortDescriptorType {
        return _SQLSortDescriptor.Desc(SQLExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.select()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func aliased(alias: String) -> _SQLSelectable {
        return _SQLResultColumn.Expression(SQLExpression, alias)
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
    case Value(DatabaseValueConvertible?)
    
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
    
    /// For example: `age BETWEEN 1 AND 2`
    case Between(value: _SQLExpression, min: _SQLExpression, max: _SQLExpression)
    
    /// For example: `LOWER(name)`
    case Function(String, [_SQLExpression])
    
    /// For example: `COUNT(*)`
    case Count(_SQLSelectable)
    
    /// For example: `COUNT(DISTINCT name)`
    case CountDistinct(_SQLExpression)
    
    ///
    func sql(inout bindings: [DatabaseValueConvertible?]) throws -> String {
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
            let sql = try expression.sql(&bindings)
            let chars = sql.characters
            if chars.last! == ")" {
                return String(chars.prefixUpTo(chars.endIndex.predecessor())) + " COLLATE " + collation + ")"
            } else {
                return sql + " COLLATE " + collation
            }
            
        case .Not(let condition):
            switch condition {
            case .Not(let expression):
                return try expression.sql(&bindings)
            case .In(let expressions, let expression):
                if expressions.isEmpty {
                    return "1"
                } else {
                    return try "(" + expression.sql(&bindings) + " NOT IN (" + expressions.map { try $0.sql(&bindings) }.joinWithSeparator(", ") + "))"
                }
            case .Equal(let lhs, let rhs):
                return try _SQLExpression.NotEqual(lhs, rhs).sql(&bindings)
            case .NotEqual(let lhs, let rhs):
                return try _SQLExpression.Equal(lhs, rhs).sql(&bindings)
            case .Is(let lhs, let rhs):
                return try _SQLExpression.IsNot(lhs, rhs).sql(&bindings)
            case .IsNot(let lhs, let rhs):
                return try _SQLExpression.Is(lhs, rhs).sql(&bindings)
            default:
                return try "(NOT " + condition.sql(&bindings) + ")"
            }
            
        case .Equal(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs == nil:
                // Swiftism!
                // Turn `filter(a == nil)` into `a IS NULL` since the intention is obviously to check for NULL. `a = NULL` would evaluate to NULL.
                return try "(" + lhs.sql(&bindings) + " IS NULL)"
            case (.Value(let lhs), let rhs) where lhs == nil:
                // Swiftism!
                return try "(" + rhs.sql(&bindings) + " IS NULL)"
            default:
                return try "(" + lhs.sql(&bindings) + " = " + rhs.sql(&bindings) + ")"
            }
            
        case .NotEqual(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs == nil:
                // Swiftism!
                // Turn `filter(a != nil)` into `a IS NOT NULL` since the intention is obviously to check for NULL. `a <> NULL` would evaluate to NULL.
                return try "(" + lhs.sql(&bindings) + " IS NOT NULL)"
            case (.Value(let lhs), let rhs) where lhs == nil:
                // Swiftism!
                return try "(" + rhs.sql(&bindings) + " IS NOT NULL)"
            default:
                return try "(" + lhs.sql(&bindings) + " <> " + rhs.sql(&bindings) + ")"
            }
            
        case .Is(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs == nil:
                return try "(" + lhs.sql(&bindings) + " IS NULL)"
            case (.Value(let lhs), let rhs) where lhs == nil:
                return try "(" + rhs.sql(&bindings) + " IS NULL)"
            default:
                return try "(" + lhs.sql(&bindings) + " IS " + rhs.sql(&bindings) + ")"
            }
            
        case .IsNot(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs == nil:
                return try "(" + lhs.sql(&bindings) + " IS NOT NULL)"
            case (.Value(let lhs), let rhs) where lhs == nil:
                return try "(" + rhs.sql(&bindings) + " IS NOT NULL)"
            default:
                return try "(" + lhs.sql(&bindings) + " IS NOT " + rhs.sql(&bindings) + ")"
            }
            
        case .PrefixOperator(let SQLOperator, let value):
            return try SQLOperator + value.sql(&bindings)
            
        case .InfixOperator(let SQLOperator, let lhs, let rhs):
            return try "(" + lhs.sql(&bindings) + " \(SQLOperator) " + rhs.sql(&bindings) + ")"
            
        case .In(let expressions, let expression):
            guard !expressions.isEmpty else {
                return "0"
            }
            return try "(" + expression.sql(&bindings) + " IN (" + expressions.map { try $0.sql(&bindings) }.joinWithSeparator(", ")  + "))"
            
        case .Between(value: let value, min: let min, max: let max):
            return try "(" + value.sql(&bindings) + " BETWEEN " + min.sql(&bindings) + " AND " + max.sql(&bindings) + ")"
            
        case .Function(let functionName, let functionArguments):
            return try functionName + "(" + functionArguments.map { try $0.sql(&bindings) }.joinWithSeparator(", ")  + ")"
            
        case .Count(let counted):
            return try "COUNT(" + counted.countedSQL(&bindings) + ")"
            
        case .CountDistinct(let expression):
            return try "COUNT(DISTINCT " + expression.sql(&bindings) + ")"
        }
    }
}

extension _SQLExpression : _DerivedSQLExpressionType {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var SQLExpression: _SQLExpression {
        return self
    }
}


// MARK: - _SQLSelectable

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLSelectable {
    func resultColumnSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String
    func countedSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String
}

enum _SQLResultColumn {
    case Star(String?)
    case Expression(_SQLExpression, String)
}

extension _SQLResultColumn : _SQLSelectable {
    
    func resultColumnSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String {
        switch self {
        case .Star(let sourceName):
            if let sourceName = sourceName {
                return sourceName.quotedDatabaseIdentifier + ".*"
            } else {
                return "*"
            }
        case .Expression(let expression, let identifier):
            return try expression.sql(&bindings) + " AS " + identifier.quotedDatabaseIdentifier
        }
    }
    
    func countedSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String {
        switch self {
        case .Star:
            return "*"
        case .Expression(let expression, _):
            return try expression.sql(&bindings)
        }
    }
}


// MARK: SQLLiteral

struct SQLLiteral {
    let sql: String
    init(_ sql: String) {
        self.sql = sql
    }
}

extension SQLLiteral : _DerivedSQLExpressionType {
    var SQLExpression: _SQLExpression {
        return .Literal(sql)
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

extension SQLColumn : _DerivedSQLExpressionType {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var SQLExpression: _SQLExpression {
        return .Identifier(identifier: name, sourceName: sourceName)
    }
}
