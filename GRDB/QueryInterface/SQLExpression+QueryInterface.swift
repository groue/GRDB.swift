// MARK: - SQLExpression

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Converts an expression to an SQLExpressionLiteral
    ///
    /// :nodoc:
    public var literal: SQLExpressionLiteral {
        var context = SQLGenerationContext.literalGenerationContext(withArguments: true)
        let sql = expressionSQL(&context)
        return SQLExpressionLiteral(sql, arguments: context.arguments)
    }
    
    /// The expression as a quoted SQL literal (not public in order to avoid abuses)
    ///
    ///     "foo'bar".databaseValue.sql  // "'foo''bar'""
    var sql: String {
        var context = SQLGenerationContext.literalGenerationContext(withArguments: false)
        return expressionSQL(&context)
    }
}

// MARK: - SQLExpressionLiteral

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionLiteral is an expression built from a raw SQL snippet.
///
///     SQLExpressionLiteral("1 + 2")
///
/// The SQL literal may contain `?` and colon-prefixed tokens:
///
///     SQLExpressionLiteral("? + ?", arguments: [1, 2])
///     SQLExpressionLiteral(":one + :two", arguments: ["one": 1, "two": 2])
public struct SQLExpressionLiteral : SQLExpression {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The SQL literal
    public let sql: String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Eventual arguments that feed the `?` and colon-prefixed tokens in the
    /// SQL literal
    public let arguments: StatementArguments?
    
    /// If safe, an SQLExpressionLiteral("foo") wraps itself in parenthesis,
    /// and outputs "(foo)" in SQL queries. This avoids any bug due to operator
    /// precedence. When unsafe, the expression literal does not wrap itself
    /// in parenthesis and outputs its raw sql.
    var unsafeRaw: Bool = false
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates an SQL literal expression.
    ///
    ///     SQLExpressionLiteral("1 + 2")
    ///     SQLExpressionLiteral("? + ?", arguments: [1, 2])
    ///     SQLExpressionLiteral(":one + :two", arguments: ["one": 1, "two": 2])
    public init(_ sql: String, arguments: StatementArguments? = nil) {
        self.sql = sql
        self.arguments = arguments
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        if let arguments = arguments {
            if context.appendArguments(arguments) == false {
                // GRDB limitation: we don't know how to look for `?` in sql and
                // replace them with with literals.
                fatalError("Not implemented")
            }
        }
        if unsafeRaw {
            return sql
        } else {
            return "(" + sql + ")"
        }
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return self
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return self
    }
}

// MARK: - SQLExpressionUnary

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLUnaryOperator is a SQLite unary operator.
///
/// :nodoc:
public struct SQLUnaryOperator : Hashable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The SQL operator
    public let sql: String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// If true GRDB puts a white space between the operator and the operand.
    public let needsRightSpace: Bool
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates an unary operator
    ///
    ///     SQLUnaryOperator("~", needsRightSpace: false)
    public init(_ sql: String, needsRightSpace: Bool) {
        self.sql = sql
        self.needsRightSpace = needsRightSpace
    }
    
    /// The hash value
    ///
    /// :nodoc:
    public var hashValue: Int {
        return sql.hashValue
    }
    
    /// Equality operator
    ///
    /// :nodoc:
    public static func == (lhs: SQLUnaryOperator, rhs: SQLUnaryOperator) -> Bool {
        return lhs.sql == rhs.sql
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionUnary is an expression made of an unary operator and
/// an operand expression.
///
/// :nodoc:
public struct SQLExpressionUnary : SQLExpression {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The unary operator
    public let op: SQLUnaryOperator
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The operand
    public let expression: SQLExpression
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates an expression made of an unary operator and
    /// an operand expression.
    ///
    ///     // NOT favorite
    ///     SQLExpressionUnary(.not, Column("favorite"))
    public init(_ op: SQLUnaryOperator, _ value: SQLExpressible) {
        self.op = op
        self.expression = value.sqlExpression
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return op.sql + (op.needsRightSpace ? " " : "") + expression.expressionSQL(&context)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionUnary(op, expression.qualifiedExpression(with: alias))
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionUnary(op, expression.resolvedExpression(inContext: context))
    }
}

// MARK: - SQLExpressionBinary

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLBinaryOperator is a SQLite binary operator.
///
/// :nodoc:
public struct SQLBinaryOperator : Hashable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The SQL operator
    public let sql: String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The SQL for the negated operator, if any
    public let negatedSQL: String?
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates a binary operator
    ///
    ///     SQLBinaryOperator("+")
    ///     SQLBinaryOperator("IS", negated: "IS NOT")
    public init(_ sql: String, negated: String? = nil) {
        self.sql = sql
        self.negatedSQL = negated
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Returns the negated binary operator, if any
    ///
    ///     let operator = SQLBinaryOperator("IS", negated: "IS NOT")
    ///     operator.negated!.sql  // IS NOT
    public var negated: SQLBinaryOperator? {
        guard let negatedSQL = negatedSQL else {
            return nil
        }
        return SQLBinaryOperator(negatedSQL, negated: sql)
    }
    
    /// The hash value
    public var hashValue: Int {
        return sql.hashValue
    }
    
    /// Equality operator
    public static func == (lhs: SQLBinaryOperator, rhs: SQLBinaryOperator) -> Bool {
        return lhs.sql == rhs.sql
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionBinary is an expression made of two expressions joined with a
/// binary operator.
///
///     SQLExpressionBinary(.multiply, Column("length"), Column("width"))
///
/// :nodoc:
public struct SQLExpressionBinary : SQLExpression {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The left operand
    public let lhs: SQLExpression
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The operator
    public let op: SQLBinaryOperator
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The right operand
    public let rhs: SQLExpression
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates an expression made of two expressions joined with a
    /// binary operator.
    ///
    ///     // length * width
    ///     SQLExpressionBinary(.multiply, Column("length"), Column("width"))
    public init(_ op: SQLBinaryOperator, _ lhs: SQLExpressible, _ rhs: SQLExpressible) {
        self.lhs = lhs.sqlExpression
        self.op = op
        self.rhs = rhs.sqlExpression
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return "(" + lhs.expressionSQL(&context) + " " + op.sql + " " + rhs.expressionSQL(&context) + ")"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public var negated: SQLExpression {
        if let negatedOp = op.negated {
           return SQLExpressionBinary(negatedOp, lhs, rhs)
        } else {
            return SQLExpressionNot(self)
        }
    }
        
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionBinary(op, lhs.qualifiedExpression(with: alias), rhs.qualifiedExpression(with: alias))
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionBinary(op, lhs.resolvedExpression(inContext: context), rhs.resolvedExpression(inContext: context))
    }
}

// MARK: - SQLExpressionAnd

struct SQLExpressionAnd : SQLExpression {
    let expressions: [SQLExpression]
    
    init(_ expressions: [SQLExpression]) {
        self.expressions = expressions
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        guard let first = expressions.first else {
            // Ruby [].all? # => true
            return true.sqlExpression.expressionSQL(&context)
        }
        if expressions.count == 1 {
            return first.expressionSQL(&context)
        }
        let expressionSQLs = expressions.map { $0.expressionSQL(&context) }
        return "(" + expressionSQLs.joined(separator: " AND ") + ")"
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionAnd(expressions.map { $0.qualifiedExpression(with: alias) })
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionAnd(expressions.map { $0.resolvedExpression(inContext: context) })
    }
    
    func matchedRowIds(rowIdName: String?) -> Set<Int64>? {
        let matchedRowIds = expressions.compactMap {
            $0.matchedRowIds(rowIdName: rowIdName)
        }
        guard let first = matchedRowIds.first else {
            return nil
        }
        return matchedRowIds.suffix(from: 1).reduce(into: first) { $0.formIntersection($1) }
    }
}

// MARK: - SQLExpressionOr

struct SQLExpressionOr : SQLExpression {
    let expressions: [SQLExpression]
    
    init(_ expressions: [SQLExpression]) {
        self.expressions = expressions
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        guard let first = expressions.first else {
            // Ruby [].any? # => false
            return false.sqlExpression.expressionSQL(&context)
        }
        if expressions.count == 1 {
            return first.expressionSQL(&context)
        }
        let expressionSQLs = expressions.map { $0.expressionSQL(&context) }
        return "(" + expressionSQLs.joined(separator: " OR ") + ")"
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionOr(expressions.map { $0.qualifiedExpression(with: alias) })
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionOr(expressions.map { $0.resolvedExpression(inContext: context) })
    }
    
    func matchedRowIds(rowIdName: String?) -> Set<Int64>? {
        if expressions.isEmpty {
            return []
        }
        var result: Set<Int64> = []
        for expr in expressions {
            guard let matchedRowIds = expr.matchedRowIds(rowIdName: rowIdName) else {
                return nil
            }
            result.formUnion(matchedRowIds)
        }
        return result
    }
}

// MARK: - SQLExpressionEqual

struct SQLExpressionEqual: SQLExpression {
    var lhs: SQLExpression
    var rhs: SQLExpression
    var op: Operator
    
    init(_ op: Operator, _ lhs: SQLExpression, _ rhs: SQLExpression) {
        self.lhs = lhs
        self.rhs = rhs
        self.op = op
    }
    
    enum Operator: String {
        case equal = "="
        case notEqual = "<>"
        case `is` = "IS"
        case isNot = "IS NOT"
        
        var negated: Operator {
            switch self {
            case .equal: return .notEqual
            case .notEqual: return .equal
            case .is: return .isNot
            case .isNot: return .is
            }
        }
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return "(" +
            lhs.expressionSQL(&context) +
            " " +
            op.rawValue +
            " " +
            rhs.expressionSQL(&context) +
        ")"
    }
    
    var negated: SQLExpression {
        return SQLExpressionEqual(op.negated, lhs, rhs)
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionEqual(op, lhs.qualifiedExpression(with: alias), rhs.qualifiedExpression(with: alias))
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionEqual(op, lhs.resolvedExpression(inContext: context), rhs.resolvedExpression(inContext: context))
    }
    
    func matchedRowIds(rowIdName: String?) -> Set<Int64>? {
        // FIXME: this implementation ignores column aliases
        switch op {
        case .equal, .is:
            // Look for `id ==/IS 1`, `rowid ==/IS 1`, `1 ==/IS id`, `1 ==/IS rowid`
            func matchedRowIds(column: ColumnExpression, dbValue: DatabaseValue) -> Set<Int64>? {
                var rowIdNames = [Column.rowID.name.lowercased()]
                if let rowIdName = rowIdName {
                    rowIdNames.append(rowIdName.lowercased())
                }
                guard rowIdNames.contains(column.name.lowercased()) else {
                    return nil
                }
                if let rowId = Int64.fromDatabaseValue(dbValue) {
                    return [rowId]
                } else {
                    return []
                }
            }
            switch (lhs, rhs) {
            case (let column as ColumnExpression, let dbValue as DatabaseValue):
                return matchedRowIds(column: column, dbValue: dbValue)
            case (let dbValue as DatabaseValue, let column as ColumnExpression):
                return matchedRowIds(column: column, dbValue: dbValue)
            default:
                return nil
            }
            
        case .notEqual, .isNot:
            return nil
        }
    }
}

// MARK: - SQLExpressionContains

/// SQLExpressionContains is an expression that checks the inclusion of a
/// value in a collection with the `IN` operator.
///
///     // id IN (1,2,3)
///     SQLExpressionContains(Column("id"), SQLExpressionsArray([1,2,3]))
struct SQLExpressionContains : SQLExpression {
    let expression: SQLExpression
    let collection: SQLCollection
    let isNegated: Bool
    
    init(_ value: SQLExpressible, _ collection: SQLCollection, negated: Bool = false) {
        self.expression = value.sqlExpression
        self.collection = collection
        self.isNegated = negated
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return "(" +
            expression.expressionSQL(&context) +
            (isNegated ? " NOT IN (" : " IN (") +
            collection.collectionSQL(&context) +
        "))"
    }
    
    var negated: SQLExpression {
        return SQLExpressionContains(expression, collection, negated: !isNegated)
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionContains(expression.qualifiedExpression(with: alias), collection, negated: isNegated)
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionContains(expression.resolvedExpression(inContext: context), collection, negated: isNegated)
    }
    
    func matchedRowIds(rowIdName: String?) -> Set<Int64>? {
        // FIXME: this implementation ignores column aliases
        // Look for `id IN (1, 2, 3)`
        guard let column = expression as? ColumnExpression,
            let array = collection as? SQLExpressionsArray else
        {
            return nil
        }
        
        var rowIdNames = [Column.rowID.name.lowercased()]
        if let rowIdName = rowIdName {
            rowIdNames.append(rowIdName.lowercased())
        }
        
        guard rowIdNames.contains(column.name.lowercased()) else {
            return nil
        }
        
        var rowIDs: Set<Int64> = []
        for expression in array.expressions {
            guard let dbValue = expression as? DatabaseValue else { return nil }
            if let rowId = Int64.fromDatabaseValue(dbValue) {
                rowIDs.insert(rowId)
            }
        }
        return rowIDs
    }
}

// MARK: - SQLExpressionBetween

/// SQLExpressionBetween is an expression that checks if a values is included
/// in a range with the `BETWEEN` operator.
///
///     // id BETWEEN 1 AND 3
///     SQLExpressionBetween(Column("id"), 1.databaseValue, 3.databaseValue)
struct SQLExpressionBetween : SQLExpression {
    let expression: SQLExpression
    let lowerBound: SQLExpression
    let upperBound: SQLExpression
    let isNegated: Bool
    
    init(_ expression: SQLExpression, _ lowerBound: SQLExpression, _ upperBound: SQLExpression, negated: Bool = false) {
        self.expression = expression
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.isNegated = negated
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return "(" +
            expression.expressionSQL(&context) +
            (isNegated ? " NOT BETWEEN " : " BETWEEN ") +
            lowerBound.expressionSQL(&context) +
            " AND " +
            upperBound.expressionSQL(&context) +
        ")"
    }

    var negated: SQLExpression {
        return SQLExpressionBetween(expression, lowerBound, upperBound, negated: !isNegated)
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionBetween(
            expression.qualifiedExpression(with: alias),
            lowerBound.qualifiedExpression(with: alias),
            upperBound.qualifiedExpression(with: alias),
            negated: isNegated)
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionBetween(
            expression.resolvedExpression(inContext: context),
            lowerBound.resolvedExpression(inContext: context),
            upperBound.resolvedExpression(inContext: context),
            negated: isNegated)
    }
}

// MARK: - SQLExpressionFunction

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLFunctionName is an SQL function name.
public struct SQLFunctionName : Hashable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The SQL function name
    ///
    /// :nodoc:
    public var sql: String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates a function name
    ///
    ///     SQLFunctionName("ABS")
    ///
    /// :nodoc:
    public init(_ sql: String) {
        self.sql = sql
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionFunction is an SQL function call.
///
///     // ABS(-1)
///     SQLExpressionFunction(.abs, [-1.databaseValue])
///
/// :nodoc:
public struct SQLExpressionFunction : SQLExpression {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The function name
    public let functionName: SQLFunctionName
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The function arguments
    public let arguments: [SQLExpression]
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates an SQL function call
    ///
    ///     // ABS(-1)
    ///     SQLExpressionFunction(.abs, arguments: [-1.databaseValue])
    public init(_ functionName: SQLFunctionName, arguments: [SQLExpression]) {
        self.functionName = functionName
        self.arguments = arguments
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates an SQL function call
    ///
    ///     // ABS(-1)
    ///     SQLExpressionFunction(.abs, arguments: -1)
    public init(_ functionName: SQLFunctionName, arguments: SQLExpressible...) {
        self.init(functionName, arguments: arguments.map { $0.sqlExpression })
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return functionName.sql + "(" + (self.arguments.map { $0.expressionSQL(&context) } as [String]).joined(separator: ", ")  + ")"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionFunction(functionName, arguments: arguments.map { $0.qualifiedExpression(with: alias) })
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionFunction(functionName, arguments: arguments.map { $0.resolvedExpression(inContext: context) })
    }
}

// MARK: - SQLExpressionCount

/// SQLExpressionCount is a call to the SQL `COUNT` function.
///
///     // COUNT(name)
///     SQLExpressionCount(Column("name"))
struct SQLExpressionCount : SQLExpression {
    /// The counted value
    let counted: SQLSelectable
    
    init(_ counted: SQLSelectable) {
        self.counted = counted
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return "COUNT(" + counted.countedSQL(&context) + ")"
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionCount(counted.qualifiedSelectable(with: alias))
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return self
    }
}

// MARK: - SQLExpressionCountDistinct

/// SQLExpressionCountDistinct is a call to the SQL `COUNT(DISTINCT ...)` function.
///
///     // COUNT(DISTINCT name)
///     SQLExpressionCountDistinct(Column("name"))
struct SQLExpressionCountDistinct : SQLExpression {
    let counted: SQLExpression
    
    init(_ counted: SQLExpression) {
        self.counted = counted
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return "COUNT(DISTINCT " + counted.expressionSQL(&context) + ")"
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionCountDistinct(counted.qualifiedExpression(with: alias))
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return self
    }
}

// MARK: - TableMatchExpression

struct TableMatchExpression: SQLExpression {
    var alias: TableAlias
    var pattern: SQLExpression
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        return "(" + context.resolvedName(for: alias).quotedDatabaseIdentifier + " MATCH " + pattern.expressionSQL(&context) + ")"
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return TableMatchExpression(
            alias: self.alias,
            pattern: pattern.qualifiedExpression(with: alias))
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return TableMatchExpression(
            alias: alias,
            pattern: pattern.resolvedExpression(inContext: context))
    }
}

// MARK: - SQLExpressionCollate

/// SQLExpressionCollate is an expression tainted by an SQLite collation.
///
///     // email = 'arthur@example.com' COLLATE NOCASE
///     SQLExpressionCollate(Column("email") == "arthur@example.com", "NOCASE")
struct SQLExpressionCollate : SQLExpression {
    let expression: SQLExpression
    let collationName: Database.CollationName
    
    init(_ expression: SQLExpression, collationName: Database.CollationName) {
        self.expression = expression
        self.collationName = collationName
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext) -> String {
        let sql = expression.expressionSQL(&context)
        if sql.last! == ")" {
            return String(sql.prefix(upTo: sql.index(sql.endIndex, offsetBy: -1))) + " COLLATE " + collationName.rawValue + ")"
        } else {
            return sql + " COLLATE " + collationName.rawValue
        }
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionCollate(expression.qualifiedExpression(with: alias), collationName: collationName)
    }
    
    func resolvedExpression(inContext context: [TableAlias: PersistenceContainer]) -> SQLExpression {
        return SQLExpressionCollate(expression.resolvedExpression(inContext: context), collationName: collationName)
    }
}
