// MARK: - SQLExpression

extension SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Converts an expression to an SQLExpressionLiteral
    public var literal: SQLExpressionLiteral {
        var arguments: StatementArguments? = []
        let sql = expressionSQL(&arguments)
        return SQLExpressionLiteral(sql, arguments: arguments)
    }
    
    /// The expression as a quoted SQL literal (not public in order to avoid abuses)
    ///
    ///     "foo'bar".databaseValue.sql  // "'foo''bar'""
    var sql: String {
        var arguments: StatementArguments? = nil
        return expressionSQL(&arguments)
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
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        if let literalArguments = self.arguments {
            guard arguments != nil else {
                // GRDB limitation: we don't know how to look for `?` in sql and
                // replace them with with literals.
                fatalError("Not implemented")
            }
            arguments! += literalArguments
        }
        return sql
    }
}

// MARK: - SQLExpressionUnary

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLUnaryOperator is a SQLite unary operator.
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
    public var hashValue: Int {
        return sql.hashValue
    }
    
    /// Equality operator
    public static func == (lhs: SQLUnaryOperator, rhs: SQLUnaryOperator) -> Bool {
        return lhs.sql == rhs.sql
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionUnary is an expression made of an unary operator and
/// an operand expression.
///
///     SQLExpressionUnary(.not, Column("favorite"))
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
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return op.sql + (op.needsRightSpace ? " " : "") + expression.expressionSQL(&arguments)
    }
}

// MARK: - SQLExpressionBinary

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLBinaryOperator is a SQLite binary operator.
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
    
    // TODO: make it an extension of Sequence (like joined(separator:)) when Swift can better handle existentials
    // TODO: make it public eventually
    /// Return nil if expressions is empty.
    func join(_ expressions: [SQLExpression]) -> SQLExpression? {
        switch expressions.count {
        case 0:
            return nil
        case 1:
            return expressions[0]
        default:
            let literals = expressions.map { $0.literal }
            let firstLiteral = literals[0]
            var sql = firstLiteral.sql
            var arguments = firstLiteral.arguments ?? StatementArguments()
            for literal in literals.suffix(from: 1) {
                sql += " \(self.sql) \(literal.sql)"
                if let args = literal.arguments {
                    arguments += args
                }
            }
            return SQLExpressionLiteral("(\(sql))", arguments: arguments.isEmpty ? nil : arguments)
        }
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionBinary is an expression made of two expressions joined with a
/// binary operator.
///
///     SQLExpressionBinary(.multiply, Column("length"), Column("width"))
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
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return "(" + lhs.expressionSQL(&arguments) + " " + op.sql + " " + rhs.expressionSQL(&arguments) + ")"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public var negated: SQLExpression {
        if let negatedOp = op.negated {
           return SQLExpressionBinary(negatedOp, lhs, rhs)
        } else {
            return SQLExpressionNot(self)
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
    
    func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return "(" +
            expression.expressionSQL(&arguments) +
            (isNegated ? " NOT IN (" : " IN (") +
            collection.collectionSQL(&arguments) +
        "))"
    }
    
    var negated: SQLExpression {
        return SQLExpressionContains(expression, collection, negated: !isNegated)
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
    
    func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return "(" +
            expression.expressionSQL(&arguments) +
            (isNegated ? " NOT BETWEEN " : " BETWEEN ") +
            lowerBound.expressionSQL(&arguments) +
            " AND " +
            upperBound.expressionSQL(&arguments) +
        ")"
    }

    var negated: SQLExpression {
        return SQLExpressionBetween(expression, lowerBound, upperBound, negated: !isNegated)
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
    public let sql: String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Creates a function name
    ///
    ///     SQLFunctionName("ABS")
    public init(_ sql: String) {
        self.sql = sql
    }
    
    /// The hash value
    public var hashValue: Int {
        return sql.hashValue
    }
    
    /// Equality operator
    public static func == (lhs: SQLFunctionName, rhs: SQLFunctionName) -> Bool {
        return lhs.sql == rhs.sql
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLExpressionFunction is an SQL function call.
///
///     // ABS(-1)
///     SQLExpressionFunction(.abs, [-1.databaseValue])
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
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return functionName.sql + "(" + (self.arguments.map { $0.expressionSQL(&arguments) } as [String]).joined(separator: ", ")  + ")"
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
    
    func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return "COUNT(" + counted.countedSQL(&arguments) + ")"
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
    
    func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return "COUNT(DISTINCT " + counted.expressionSQL(&arguments) + ")"
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
    
    func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        let sql = expression.expressionSQL(&arguments)
        if sql.last! == ")" {
            return String(sql.prefix(upTo: sql.index(sql.endIndex, offsetBy: -1))) + " COLLATE " + collationName.rawValue + ")"
        } else {
            return sql + " COLLATE " + collationName.rawValue
        }
    }
}
