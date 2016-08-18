

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
    // such as SQLColumn and _SQLExpression.
    //
    // This separation lets us define functions and operators that do not
    // spill out. The three declarations below have no chance overloading a
    // Swift-defined operator, or a user-defined operator:
    //
    // - ==(SQLExpressible, _SpecificSQLExpressible)
    // - ==(_SpecificSQLExpressible, SQLExpressible)
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
    public func orderingSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        return try sqlExpression.sql(db, &arguments)
    }
}

extension _SpecificSQLExpressible where Self: SQLSelectable {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func selectionSQL(db: Database, from querySource: SQLSource?, inout _ arguments: StatementArguments?) throws -> String {
        return try sqlExpression.sql(db, &arguments)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func countedSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        return try sqlExpression.sql(db, &arguments)
    }
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var selectableKind: _SQLSelectableKind {
        return .Expression(expression: sqlExpression)
    }
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func numberOfColumns(db: Database) throws -> Int {
        return 1
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
    public func aliased(alias: String) -> SQLSelectable {
        return _SQLSelectionElement.Expression(expression: sqlExpression, alias: alias)
    }
}


// MARK: - SQLColumn

/// A column in the database
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct SQLColumn {
    let source: SQLSource?
    
    /// The name of the column
    public let name: String
    
    /// Initializes a column given its name.
    public init(_ name: String) {
        self.name = name
        self.source = nil
    }
    
    init(_ name: String, source: SQLSource?) {
        self.name = name
        self.source = source
    }
}

extension SQLColumn : _SpecificSQLExpressible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlExpression: _SQLExpression {
        return .Identifier(identifier: name, source: source)
    }
}

extension SQLColumn : SQLSelectable {}
extension SQLColumn : _SQLOrdering {}


// MARK: - _SQLExpression

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public indirect enum _SQLExpression {
    /// For example: `name || 'rrr' AS pirateName`
    case Literal(String, StatementArguments?)
    
    /// For example: `1` or `'foo'`
    case Value(DatabaseValue)
    
    /// For example: `name`, `table.name`
    case Identifier(identifier: String, source: SQLSource?)
    
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
    case InSubQuery(SQLSelectQueryDefinition, _SQLExpression)
    
    /// For example `EXISTS (SELECT ...)`
    case Exists(SQLSelectQueryDefinition)
    
    /// For example: `age BETWEEN 1 AND 2`
    case Between(value: _SQLExpression, min: _SQLExpression, max: _SQLExpression)
    
    /// For example: `LOWER(name)`
    case Function(String, [_SQLExpression])
    
    /// For example: `COUNT(name)`
    case Count(_SQLExpression)
    
    /// For example: `COUNT(DISTINCT name)`
    case CountDistinct(_SQLExpression)
    
    /// For example: `COUNT(*)`
    case CountAll
    
    ///
    func sql(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        switch self {
        case .Literal(let sql, let literalArguments):
            if let literalArguments = literalArguments {
                guard arguments != nil else {
                    fatalError("Not implemented")
                }
                arguments!.values.appendContentsOf(literalArguments.values)
                for (name, value) in literalArguments.namedValues {
                    guard arguments!.namedValues[name] == nil else {
                        fatalError("argument \(String(reflecting: name)) can't be reused")
                    }
                    arguments!.namedValues[name] = value
                }
            }
            return sql
            
        case .Value(let value):
            if arguments == nil {
                return value.sqlLiteral
            } else {
                arguments!.values.append(value)
                return "?"
            }
            
        case .Identifier(let identifier, let source):
            if let source = source {
                return source.name.quotedDatabaseIdentifier + "." + identifier.quotedDatabaseIdentifier
            } else {
                return identifier.quotedDatabaseIdentifier
            }
            
        case .Collate(let expression, let collation):
            let sql = try expression.sql(db, &arguments)
            let chars = sql.characters
            if chars.last! == ")" {
                return String(chars.prefixUpTo(chars.endIndex.predecessor())) + " COLLATE " + collation + ")"
            } else {
                return sql + " COLLATE " + collation
            }
            
        case .Not(let condition):
            switch condition {
            case .Not(let expression):
                return try expression.sql(db, &arguments)
                
            case .In(let expressions, let expression):
                if expressions.isEmpty {
                    return "1"
                } else {
                    return try "(" + expression.sql(db, &arguments) + " NOT IN (" + (expressions.map { try $0.sql(db, &arguments) } as [String]).joinWithSeparator(", ") + "))"
                }
                
            case .InSubQuery(let subQuery, let expression):
                return try "(" + expression.sql(db, &arguments) + " NOT IN (" + subQuery.makeSelectQuery(db).sql(db, &arguments)  + "))"
                
            case .Exists(let subQuery):
                return try "(NOT EXISTS (" + subQuery.makeSelectQuery(db).sql(db, &arguments)  + "))"
                
            case .Equal(let lhs, let rhs):
                return try _SQLExpression.NotEqual(lhs, rhs).sql(db, &arguments)
                
            case .NotEqual(let lhs, let rhs):
                return try _SQLExpression.Equal(lhs, rhs).sql(db, &arguments)
                
            case .Is(let lhs, let rhs):
                return try _SQLExpression.IsNot(lhs, rhs).sql(db, &arguments)
                
            case .IsNot(let lhs, let rhs):
                return try _SQLExpression.Is(lhs, rhs).sql(db, &arguments)
                
            default:
                return try "(NOT " + condition.sql(db, &arguments) + ")"
            }
            
        case .Equal(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(DatabaseValue.Null)):
                // Swiftism!
                // Turn `filter(a == nil)` into `a IS NULL` since the intention is obviously to check for NULL. `a = NULL` would evaluate to NULL.
                return try "(" + lhs.sql(db, &arguments) + " IS NULL)"
            case (.Value(DatabaseValue.Null), let rhs):
                // Swiftism!
                return try "(" + rhs.sql(db, &arguments) + " IS NULL)"
            default:
                return try "(" + lhs.sql(db, &arguments) + " = " + rhs.sql(db, &arguments) + ")"
            }
            
        case .NotEqual(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(DatabaseValue.Null)):
                // Swiftism!
                // Turn `filter(a != nil)` into `a IS NOT NULL` since the intention is obviously to check for NULL. `a <> NULL` would evaluate to NULL.
                return try "(" + lhs.sql(db, &arguments) + " IS NOT NULL)"
            case (.Value(DatabaseValue.Null), let rhs):
                // Swiftism!
                return try "(" + rhs.sql(db, &arguments) + " IS NOT NULL)"
            default:
                return try "(" + lhs.sql(db, &arguments) + " <> " + rhs.sql(db, &arguments) + ")"
            }
            
        case .Is(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs.isNull:
                return try "(" + lhs.sql(db, &arguments) + " IS NULL)"
            case (.Value(let lhs), let rhs) where lhs.isNull:
                return try "(" + rhs.sql(db, &arguments) + " IS NULL)"
            default:
                return try "(" + lhs.sql(db, &arguments) + " IS " + rhs.sql(db, &arguments) + ")"
            }
            
        case .IsNot(let lhs, let rhs):
            switch (lhs, rhs) {
            case (let lhs, .Value(let rhs)) where rhs.isNull:
                return try "(" + lhs.sql(db, &arguments) + " IS NOT NULL)"
            case (.Value(let lhs), let rhs) where lhs.isNull:
                return try "(" + rhs.sql(db, &arguments) + " IS NOT NULL)"
            default:
                return try "(" + lhs.sql(db, &arguments) + " IS NOT " + rhs.sql(db, &arguments) + ")"
            }
            
        case .PrefixOperator(let SQLOperator, let value):
            return try SQLOperator + value.sql(db, &arguments)
            
        case .InfixOperator(let SQLOperator, let lhs, let rhs):
            return try "(" + lhs.sql(db, &arguments) + " \(SQLOperator) " + rhs.sql(db, &arguments) + ")"
            
        case .In(let expressions, let expression):
            guard !expressions.isEmpty else {
                return "0"
            }
            return try "(" + expression.sql(db, &arguments) + " IN (" + (expressions.map { try $0.sql(db, &arguments) } as [String]).joinWithSeparator(", ")  + "))"
            
        case .InSubQuery(let subQuery, let expression):
            return try "(" + expression.sql(db, &arguments) + " IN (" + subQuery.makeSelectQuery(db).sql(db, &arguments)  + "))"
            
        case .Exists(let subQuery):
            return try "(EXISTS (" + subQuery.makeSelectQuery(db).sql(db, &arguments)  + "))"
            
        case .Between(value: let value, min: let min, max: let max):
            return try "(" + value.sql(db, &arguments) + " BETWEEN " + min.sql(db, &arguments) + " AND " + max.sql(db, &arguments) + ")"
            
        case .Function(let functionName, let functionArguments):
            return try functionName + "(" + (functionArguments.map { try $0.sql(db, &arguments) } as [String]).joinWithSeparator(", ")  + ")"
            
        case .Count(let counted):
            return try "COUNT(" + counted.countedSQL(db, &arguments) + ")"
            
        case .CountDistinct(let expression):
            return try "COUNT(DISTINCT " + expression.sql(db, &arguments) + ")"
            
        case .CountAll:
            return "COUNT(*)"
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

extension _SQLExpression : SQLSelectable { }
extension _SQLExpression : _SQLOrdering {}


// MARK: - SQL Functions

extension DatabaseFunction {
    /// Returns an SQL expression that applies the function.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public func apply(arguments: SQLExpressible...) -> _SQLExpression {
        return .Function(name, arguments.map { $0.sqlExpression })
    }
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func abs(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("ABS", [value.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func average(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("AVG", [value.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(counted: _SpecificSQLExpressible) -> _SQLExpression {
    return .Count(counted.sqlExpression)
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(distinct value: _SpecificSQLExpressible) -> _SQLExpression {
    return .CountDistinct(value.sqlExpression)
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .Function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        return .Function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
    } else {
        return rhs.sqlExpression
    }
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func length(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("LENGTH", [value.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func max(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("MAX", [value.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func min(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("MIN", [value.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func sum(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("SUM", [value.sqlExpression])
}

extension _SpecificSQLExpressible {
    /// Returns an SQL expression that applies the Swift's built-in
    /// capitalizedString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.capitalizedString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var capitalizedString: _SQLExpression {
        return DatabaseFunction.capitalizedString.apply(sqlExpression)
    }

    /// Returns an SQL expression that applies the Swift's built-in
    /// lowercaseString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.lowercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var lowercaseString: _SQLExpression {
        return DatabaseFunction.lowercaseString.apply(sqlExpression)
    }

    /// Returns an SQL expression that applies the Swift's built-in
    /// uppercaseString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.uppercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var uppercaseString: _SQLExpression {
        return DatabaseFunction.uppercaseString.apply(sqlExpression)
    }
}

@available(iOS 9.0, OSX 10.11, *)
extension _SpecificSQLExpressible {
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedCapitalizedString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedCapitalizedString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedCapitalizedString: _SQLExpression {
        return DatabaseFunction.localizedCapitalizedString.apply(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedLowercaseString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedLowercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedLowercaseString: _SQLExpression {
        return DatabaseFunction.localizedLowercaseString.apply(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedUppercaseString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedUppercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedUppercaseString: _SQLExpression {
        return DatabaseFunction.localizedUppercaseString.apply(sqlExpression)
    }
}


// MARK: - SQL Operators


// MARK: SQL Operator =

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: SQLExpressible?) -> _SQLExpression {
    return .Equal(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(.Null))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: protocol<SQLExpressible, BooleanType>?) -> _SQLExpression {
    if let rhs = rhs {
        if rhs.boolValue {
            return lhs.sqlExpression
        } else {
            return .Not(lhs.sqlExpression)
        }
    } else {
        return .Equal(lhs.sqlExpression, .Value(.Null))
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .Equal(lhs?.sqlExpression ?? .Value(.Null), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: protocol<SQLExpressible, BooleanType>?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        if lhs.boolValue {
            return rhs.sqlExpression
        } else {
            return .Not(rhs.sqlExpression)
        }
    } else {
        return .Equal(.Value(.Null), rhs.sqlExpression)
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .Equal(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator !=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: SQLExpressible?) -> _SQLExpression {
    return .NotEqual(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(.Null))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: protocol<SQLExpressible, BooleanType>?) -> _SQLExpression {
    if let rhs = rhs {
        if rhs.boolValue {
            return .Not(lhs.sqlExpression)
        } else {
            return lhs.sqlExpression
        }
    } else {
        return .NotEqual(lhs.sqlExpression, .Value(.Null))
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .NotEqual(lhs?.sqlExpression ?? .Value(.Null), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: protocol<SQLExpressible, BooleanType>?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        if lhs.boolValue {
            return .Not(rhs.sqlExpression)
        } else {
            return rhs.sqlExpression
        }
    } else {
        return .NotEqual(.Value(.Null), rhs.sqlExpression)
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .NotEqual(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator <

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator <=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator >

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator >=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator *

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator /

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator +

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator - (prefix)

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func - (value: _SpecificSQLExpressible) -> _SQLExpression {
    return .PrefixOperator("-", value.sqlExpression)
}


// MARK: SQL Operator - (infix)

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator AND

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator BETWEEN

extension Range where Element: protocol<SQLExpressible, BidirectionalIndexType> {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SpecificSQLExpressible) -> _SQLExpression {
        return .Between(value: element.sqlExpression, min: startIndex.sqlExpression, max: endIndex.predecessor().sqlExpression)
    }
}

extension ClosedInterval where Bound: SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SpecificSQLExpressible) -> _SQLExpression {
        return .Between(value: element.sqlExpression, min: start.sqlExpression, max: end.sqlExpression)
    }
}

extension HalfOpenInterval where Bound: SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SpecificSQLExpressible) -> _SQLExpression {
        return (element >= start) && (element < end)
    }
}


// MARK: SQL Operator IN

extension SequenceType where Self.Generator.Element: SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SpecificSQLExpressible) -> _SQLExpression {
        return .In(map { $0.sqlExpression }, element.sqlExpression)
    }
}


// MARK: SQL Operator IS

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SpecificSQLExpressible, rhs: SQLExpressible?) -> _SQLExpression {
    return .Is(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(.Null))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .Is(lhs?.sqlExpression ?? .Value(.Null), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .Is(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator IS NOT

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SpecificSQLExpressible, rhs: SQLExpressible?) -> _SQLExpression {
    return .IsNot(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(.Null))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .IsNot(lhs?.sqlExpression ?? .Value(.Null), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .IsNot(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator OR

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SpecificSQLExpressible, rhs: SQLExpressible) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: SQL Operator NOT

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func ! (value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Not(value.sqlExpression)
}
