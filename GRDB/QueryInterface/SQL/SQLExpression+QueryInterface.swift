// MARK: - SQLExpression

extension SQLExpression {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Converts an expression to an SQLLiteral
    ///
    /// :nodoc:
    @available(*, deprecated, message: "Use SQLLiteral initializer instead")
    public var sqlLiteral: SQLLiteral {
        return SQLLiteral(self)
    }
    
    /// The expression as a quoted SQL literal (not public in order to avoid abuses)
    ///
    ///     "foo'bar".databaseValue.quotedSQL() // "'foo''bar'""
    func quotedSQL() -> String {
        var context = SQLGenerationContext.rawSQLContext
        return expressionSQL(&context, wrappedInParenthesis: false)
    }
}

// MARK: - SQLExpressionUnary

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLUnaryOperator is a SQLite unary operator.
///
/// :nodoc:
public struct SQLUnaryOperator: Hashable {
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
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionUnary is an expression made of an unary operator and
/// an operand expression.
///
/// :nodoc:
public struct SQLExpressionUnary: SQLExpression {
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
    public func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if wrappedInParenthesis {
            return "(\(expressionSQL(&context, wrappedInParenthesis: false)))"
        }
        return op.sql + (op.needsRightSpace ? " " : "") + expression.expressionSQL(&context, wrappedInParenthesis: true)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionUnary(op, expression.qualifiedExpression(with: alias))
    }
}

// MARK: - SQLExpressionBinary

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLBinaryOperator is an SQLite binary operator, such as >, =, etc.
///
/// :nodoc:
public struct SQLBinaryOperator: Hashable {
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
    ///     SQLBinaryOperator("-")
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
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionBinary is an expression made of two expressions joined with a
/// binary operator.
///
///     SQLExpressionBinary(.multiply, Column("length"), Column("width"))
///
/// :nodoc:
public struct SQLExpressionBinary: SQLExpression {
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
    ///     SQLExpressionBinary(.subtract, Column("score"), Column("malus"))
    public init(_ op: SQLBinaryOperator, _ lhs: SQLExpressible, _ rhs: SQLExpressible) {
        self.lhs = lhs.sqlExpression
        self.op = op
        self.rhs = rhs.sqlExpression
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if wrappedInParenthesis {
            return "(\(expressionSQL(&context, wrappedInParenthesis: false)))"
        }
        return """
            \(lhs.expressionSQL(&context, wrappedInParenthesis: true)) \
            \(op.sql) \
            \(rhs.expressionSQL(&context, wrappedInParenthesis: true))
            """
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
}

// MARK: - SQLExpressionBinaryReduce

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLAssociativeBinaryOperator is an SQLite associative binary operator, such
/// as +, *, AND, etc.
///
/// :nodoc:
public struct SQLAssociativeBinaryOperator: Hashable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The SQL operator
    public let sql: String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// The neutral value
    public let neutralValue: DatabaseValue
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// if true, (a • b) • c is strictly equal to a • (b • c).
    ///
    /// `AND`, `OR`, `||` (concat) are stricly associative.
    ///
    /// + and * are not stricly associative when applied to floating
    /// point values.
    public let strictlyAssociative: Bool
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates a binary operator
    public init(sql: String, neutralValue: DatabaseValue, strictlyAssociative: Bool) {
        self.sql = sql
        self.neutralValue = neutralValue
        self.strictlyAssociative = strictlyAssociative
    }
}

@available(*, deprecated, renamed: "SQLAssociativeBinaryOperator")
typealias SQLLogicalBinaryOperator = SQLAssociativeBinaryOperator

/// SQLExpressionBinary is an expression made of two expressions joined with a
/// binary operator.
///
///     SQLExpressionBinary(.multiply, Column("length"), Column("width"))
struct SQLExpressionBinaryReduce: SQLExpression {
    let expressions: [SQLExpression]
    let op: SQLAssociativeBinaryOperator
    
    /// Creates an expression made of expressions joined with an associative
    /// binary operator.
    ///
    ///     // length * width
    ///     SQLExpressionBinaryReduce(.multiply, [Column("length"), Column("width")])
    init(_ op: SQLAssociativeBinaryOperator, _ expressions: [SQLExpression]) {
        self.op = op
        
        // flatten when possible: a • (b • c) = a • b • c
        if op.strictlyAssociative {
            self.expressions = expressions.flatMap { expression -> [SQLExpression] in
                if let reduce = expression as? SQLExpressionBinaryReduce, reduce.op == op {
                    return reduce.expressions
                } else {
                    return [expression]
                }
            }
        } else {
            self.expressions = expressions
        }
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        guard let first = expressions.first else {
            return op.neutralValue.sqlExpression.expressionSQL(&context, wrappedInParenthesis: false)
        }
        if expressions.count == 1 {
            return first.expressionSQL(&context, wrappedInParenthesis: wrappedInParenthesis)
        }
        let expressionSQLs = expressions.map { $0.expressionSQL(&context, wrappedInParenthesis: true) }
        let joiner = " \(op.sql) "
        if wrappedInParenthesis {
            return "(\(expressionSQLs.joined(separator: joiner)))"
        } else {
            return expressionSQLs.joined(separator: joiner)
        }
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionBinaryReduce(op, expressions.map { $0.qualifiedExpression(with: alias) })
    }
    
    func matchedRowIds(rowIdName: String?) -> Set<Int64>? {
        switch op {
        case .and:
            let matchedRowIds = expressions.compactMap {
                $0.matchedRowIds(rowIdName: rowIdName)
            }
            guard let first = matchedRowIds.first else {
                return nil
            }
            return matchedRowIds.suffix(from: 1).reduce(into: first) { $0.formIntersection($1) }
        case .or:
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
        default:
            return nil
        }
    }
}

extension Sequence where Element == SQLExpression {
    /// Returns an expression by joining all elements with an SQL
    /// binary operator.
    ///
    /// For example:
    ///
    ///     // SELECT * FROM player
    ///     // WHERE (registered
    ///     //        AND (score >= 1000)
    ///     //        AND (name IS NOT NULL))
    ///     let conditions = [
    ///         Column("registered"),
    ///         Column("score") >= 1000,
    ///         Column("name") != nil]
    ///     Player.filter(conditions.joined(operator: .and))
    ///
    /// When the sequence is empty, `joined(operator:)` returns the neutral
    /// value of the operator. It is 0 (zero) for `.add`, 1 for ‘.multiply`,
    /// false for `.or`, true for `.and`...
    /// and `joined(operator: .or)` returns false:
    /// When the sequence is empty, `joined(operator: .and)` returns true,
    /// and `joined(operator: .or)` returns false:
    ///
    ///     // SELECT 0 FROM player
    ///     Player.select([].joined(operator: .add))
    ///
    ///     // SELECT * FROM player WHERE 1
    ///     Player.filter([].joined(operator: .and))
    ///
    ///     // SELECT * FROM player WHERE 0
    ///     Player.filter([].joined(operator: .or))
    public func joined(operator: SQLAssociativeBinaryOperator) -> SQLExpression {
        return SQLExpressionBinaryReduce(`operator`, Array(self))
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
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if wrappedInParenthesis {
            return "(\(expressionSQL(&context, wrappedInParenthesis: false)))"
        }
        return """
            \(lhs.expressionSQL(&context, wrappedInParenthesis: true)) \
            \(op.rawValue) \
            \(rhs.expressionSQL(&context, wrappedInParenthesis: true))
            """
    }
    
    var negated: SQLExpression {
        return SQLExpressionEqual(op.negated, lhs, rhs)
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionEqual(op, lhs.qualifiedExpression(with: alias), rhs.qualifiedExpression(with: alias))
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
            case let (column as ColumnExpression, dbValue as DatabaseValue):
                return matchedRowIds(column: column, dbValue: dbValue)
            case let (dbValue as DatabaseValue, column as ColumnExpression):
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
struct SQLExpressionContains: SQLExpression {
    let expression: SQLExpression
    let collection: SQLCollection
    let isNegated: Bool
    
    init(_ value: SQLExpressible, _ collection: SQLCollection, negated: Bool = false) {
        self.expression = value.sqlExpression
        self.collection = collection
        self.isNegated = negated
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if wrappedInParenthesis {
            return "(\(expressionSQL(&context, wrappedInParenthesis: false)))"
        }
        return """
            \(expression.expressionSQL(&context, wrappedInParenthesis: true)) \
            \(isNegated ? "NOT IN" : "IN") \
            (\(collection.collectionSQL(&context)))
            """
    }
    
    var negated: SQLExpression {
        return SQLExpressionContains(expression, collection, negated: !isNegated)
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionContains(expression.qualifiedExpression(with: alias), collection, negated: isNegated)
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
struct SQLExpressionBetween: SQLExpression {
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
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if wrappedInParenthesis {
            return "(\(expressionSQL(&context, wrappedInParenthesis: false)))"
        }
        return """
            \(expression.expressionSQL(&context, wrappedInParenthesis: true)) \
            \(isNegated ? "NOT BETWEEN" : "BETWEEN") \
            \(lowerBound.expressionSQL(&context, wrappedInParenthesis: true)) \
            AND \
            \(upperBound.expressionSQL(&context, wrappedInParenthesis: true))
            """
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
}

// MARK: - SQLExpressionFunction

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLFunctionName is an SQL function name.
public struct SQLFunctionName: Hashable {
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
public struct SQLExpressionFunction: SQLExpression {
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
    public func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        var sql = functionName.sql
        sql += "("
        sql += arguments
            .map { $0.expressionSQL(&context, wrappedInParenthesis: false) }
            .joined(separator: ", ")
        sql += ")"
        return sql
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionFunction(functionName, arguments: arguments.map { $0.qualifiedExpression(with: alias) })
    }
}

// MARK: - SQLExpressionCount

/// SQLExpressionCount is a call to the SQL `COUNT` function.
///
///     // COUNT(name)
///     SQLExpressionCount(Column("name"))
struct SQLExpressionCount: SQLExpression {
    /// The counted value
    let counted: SQLSelectable
    
    init(_ counted: SQLSelectable) {
        self.counted = counted
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        return "COUNT(" + counted.countedSQL(&context) + ")"
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionCount(counted.qualifiedSelectable(with: alias))
    }
}

// MARK: - SQLExpressionCountDistinct

/// SQLExpressionCountDistinct is a call to the SQL `COUNT(DISTINCT ...)` function.
///
///     // COUNT(DISTINCT name)
///     SQLExpressionCountDistinct(Column("name"))
struct SQLExpressionCountDistinct: SQLExpression {
    let counted: SQLExpression
    
    init(_ counted: SQLExpression) {
        self.counted = counted
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        return "COUNT(DISTINCT " + counted.expressionSQL(&context, wrappedInParenthesis: false) + ")"
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionCountDistinct(counted.qualifiedExpression(with: alias))
    }
}

// MARK: - SQLExpressionIsEmpty

/// This one helps generating `COUNT(...) = 0` or `COUNT(...) > 0` while letting
/// the user using the not `!` logical operator, or comparisons with booleans
/// such as `== true` or `== false`.
struct SQLExpressionIsEmpty: SQLExpression {
    var countExpression: SQLExpression
    var isEmpty: Bool
    
    // countExpression should be a counting expression
    init(_ countExpression: SQLExpression, isEmpty: Bool = true) {
        self.countExpression = countExpression
        self.isEmpty = isEmpty
    }
    
    var negated: SQLExpression {
        return SQLExpressionIsEmpty(countExpression, isEmpty: !isEmpty)
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if wrappedInParenthesis {
            return "(\(expressionSQL(&context, wrappedInParenthesis: false)))"
        }
        return """
            \(countExpression.expressionSQL(&context, wrappedInParenthesis: true)) \
            \(isEmpty ? "= 0" : "> 0")
            """
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionIsEmpty(countExpression.qualifiedExpression(with: alias), isEmpty: isEmpty)
    }
}

// MARK: - TableMatchExpression

struct TableMatchExpression: SQLExpression {
    var alias: TableAlias
    var pattern: SQLExpression
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if wrappedInParenthesis {
            return "(\(expressionSQL(&context, wrappedInParenthesis: false)))"
        }
        return """
            \(context.resolvedName(for: alias).quotedDatabaseIdentifier) \
            MATCH \
            \(pattern.expressionSQL(&context, wrappedInParenthesis: true))
            """
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return TableMatchExpression(
            alias: self.alias,
            pattern: pattern.qualifiedExpression(with: alias))
    }
}

// MARK: - SQLExpressionCollate

/// SQLExpressionCollate is an expression tainted by an SQLite collation.
///
///     // email = 'arthur@example.com' COLLATE NOCASE
///     SQLExpressionCollate(Column("email") == "arthur@example.com", "NOCASE")
struct SQLExpressionCollate: SQLExpression {
    let expression: SQLExpression
    let collationName: Database.CollationName
    
    init(_ expression: SQLExpression, collationName: Database.CollationName) {
        self.expression = expression
        self.collationName = collationName
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if wrappedInParenthesis {
            return "(\(expressionSQL(&context, wrappedInParenthesis: false)))"
        }
        return """
            \(expression.expressionSQL(&context, wrappedInParenthesis: false)) \
            COLLATE \
            \(collationName.rawValue)
            """
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return SQLExpressionCollate(expression.qualifiedExpression(with: alias), collationName: collationName)
    }
}
