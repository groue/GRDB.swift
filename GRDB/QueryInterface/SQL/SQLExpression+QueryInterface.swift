// MARK: - SQLExpression

extension SQLExpression {
    /// The expression as a quoted SQL literal (not public in order to avoid abuses)
    ///
    ///     try "foo'bar".databaseValue.quotedSQL(db) // "'foo''bar'""
    func quotedSQL(_ db: Database) throws -> String {
        let context = SQLGenerationContext(db, argumentsSink: .forRawSQL)
        return try _expressionSQL(context, wrappedInParenthesis: false)
    }
}

// MARK: - SQLExpressionNot

/// :nodoc:
struct SQLExpressionNot: SQLExpression {
    let expression: SQLExpression
    
    init(_ expression: SQLExpression) {
        self.expression = expression
    }
    
    // MARK: SQLExpression
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try "NOT \(expression._expressionSQL(context, wrappedInParenthesis: true))"
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            // Support `NOT (NOT expression)` as a technique to build 0 or 1
            return SQLExpressionNot(self)
        }
    }
    
    var _isConstantInRequest: Bool { expression._isConstantInRequest }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionNot(expression._qualifiedExpression(with: alias))
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool { expression._isAggregate }
}

// MARK: - SQLExpressionUnary

/// SQLUnaryOperator is a SQLite unary operator.
struct SQLUnaryOperator: Hashable {
    /// The SQL operator
    let sql: String
    
    /// If true GRDB puts a white space between the operator and the operand.
    let needsRightSpace: Bool
    
    /// Creates an unary operator
    ///
    ///     SQLUnaryOperator("~", needsRightSpace: false)
    init(_ sql: String, needsRightSpace: Bool) {
        self.sql = sql
        self.needsRightSpace = needsRightSpace
    }
    
    /// The `-` unary operator
    static let minus = SQLUnaryOperator("-", needsRightSpace: false)
}

/// SQLExpressionUnary is an expression made of an unary operator and
/// an operand expression.
///
/// :nodoc:
struct SQLExpressionUnary: SQLExpression {
    let op: SQLUnaryOperator
    let expression: SQLExpression
    
    init(_ op: SQLUnaryOperator, _ value: SQLExpressible) {
        self.op = op
        self.expression = value.sqlExpression
    }
    
    // MARK: SQLExpression
    
    func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String? {
        if acceptsBijection && op == .minus {
            return try expression._column(db, for: alias, acceptsBijection: acceptsBijection)
        }
        
        return nil
    }
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try op.sql
            + (op.needsRightSpace ? " " : "")
            + expression._expressionSQL(context, wrappedInParenthesis: true)
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    var _isConstantInRequest: Bool { expression._isConstantInRequest }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionUnary(op, expression._qualifiedExpression(with: alias))
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool { expression._isAggregate }
}

// MARK: - SQLExpressionBinary

/// SQLBinaryOperator is an SQLite binary operator, such as >, =, etc.
struct SQLBinaryOperator: Hashable {
    /// The SQL operator
    let sql: String
    
    /// The SQL for the negated operator, if any
    let negatedSQL: String?
    
    /// Creates a binary operator
    ///
    ///     SQLBinaryOperator("-")
    ///     SQLBinaryOperator("LIKE", negated: "NOT LIKE")
    init(_ sql: String, negated: String? = nil) {
        self.sql = sql
        self.negatedSQL = negated
    }
    
    /// Returns the negated binary operator, if any
    ///
    ///     let operator = SQLBinaryOperator("IS", negated: "IS NOT")
    ///     operator.negated!.sql  // IS NOT
    var negated: SQLBinaryOperator? {
        guard let negatedSQL = negatedSQL else {
            return nil
        }
        return SQLBinaryOperator(negatedSQL, negated: sql)
    }
    
    /// The `<` binary operator
    static let lessThan = SQLBinaryOperator("<")
    
    /// The `<=` binary operator
    static let lessThanOrEqual = SQLBinaryOperator("<=")
    
    /// The `>` binary operator
    static let greaterThan = SQLBinaryOperator(">")
    
    /// The `>=` binary operator
    static let greaterThanOrEqual = SQLBinaryOperator(">=")
    
    /// The `-` binary operator
    static let subtract = SQLBinaryOperator("-")
    
    /// The `/` binary operator
    static let divide = SQLBinaryOperator("/")
    
    /// The `LIKE` binary operator
    static let like = SQLBinaryOperator("LIKE", negated: "NOT LIKE")
    
    /// The `MATCH` binary operator
    static let match = SQLBinaryOperator("MATCH")
}

/// SQLExpressionBinary is an expression made of two expressions joined with a
/// binary operator.
///
///     SQLExpressionBinary(.multiply, Column("length"), Column("width"))
///
/// :nodoc:
struct SQLExpressionBinary: SQLExpression {
    let lhs: SQLExpression
    let op: SQLBinaryOperator
    let rhs: SQLExpression
    
    /// Creates an expression made of two expressions joined with a
    /// binary operator.
    ///
    ///     // length * width
    ///     SQLExpressionBinary(.subtract, Column("score"), Column("malus"))
    init(_ op: SQLBinaryOperator, _ lhs: SQLExpressible, _ rhs: SQLExpressible) {
        self.lhs = lhs.sqlExpression
        self.op = op
        self.rhs = rhs.sqlExpression
    }
    
    // MARK: SQLExpression
    
    func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String? {
        guard acceptsBijection && op == .subtract else {
            return nil
        }
        
        if lhs._isConstantInRequest {
            return try rhs._column(db, for: alias, acceptsBijection: acceptsBijection)
        } else if rhs._isConstantInRequest {
            return try lhs._column(db, for: alias, acceptsBijection: acceptsBijection)
        } else {
            return nil
        }
    }
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try """
            \(lhs._expressionSQL(context, wrappedInParenthesis: true)) \
            \(op.sql) \
            \(rhs._expressionSQL(context, wrappedInParenthesis: true))
            """
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            if let negatedOp = op.negated {
                return SQLExpressionBinary(negatedOp, lhs, rhs)
            } else {
                return SQLExpressionNot(self)
            }
        }
    }
    
    var _isConstantInRequest: Bool {
        lhs._isConstantInRequest && rhs._isConstantInRequest
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionBinary(op, lhs._qualifiedExpression(with: alias), rhs._qualifiedExpression(with: alias))
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool {
        lhs._isAggregate || rhs._isAggregate
    }
}

// MARK: - SQLExpressionAssociativeBinary

/// SQLAssociativeBinaryOperator is an SQLite associative binary operator, such
/// as `+`, `*`, `AND`, etc.
///
/// Use it with the `joined(operator:)` method. For example:
///
///     // SELECT score + bonus + 1000 FROM player
///     let values = [
///         scoreColumn,
///         bonusColumn,
///         1000.databaseValue]
///     Player.select(values.joined(operator: .add))
public struct SQLAssociativeBinaryOperator: Hashable {
    /// The SQL operator
    let sql: String
    
    /// The neutral value
    let neutralValue: DatabaseValue
    
    /// If true, (a • b) • c is strictly equal to a • (b • c).
    ///
    /// `AND`, `OR`, `||` (concat) are stricly associative.
    ///
    /// `+` and `*` are not stricly associative when applied to floating
    /// point values.
    let isStrictlyAssociative: Bool
    
    /// If true, (a • b) is a bijective function of a, and a bijective
    /// function of b.
    ///
    /// `+` and `||` (concat) are bijective.
    ///
    /// `AND`, `OR` and `*` are not.
    let isBijective: Bool
    
    /// Creates a binary operator
    init(sql: String, neutralValue: DatabaseValue, strictlyAssociative: Bool, bijective: Bool) {
        self.sql = sql
        self.neutralValue = neutralValue
        self.isStrictlyAssociative = strictlyAssociative
        self.isBijective = bijective
    }
    
    /// The `+` binary operator
    ///
    /// For example:
    ///
    ///     // score + bonus
    ///     [Column("score"), Column("bonus")].joined(operator: .add)
    public static let add = SQLAssociativeBinaryOperator(
        sql: "+",
        neutralValue: 0.databaseValue,
        strictlyAssociative: false,
        bijective: true)
    
    /// The `*` binary operator
    ///
    /// For example:
    ///
    ///     // score * factor
    ///     [Column("score"), Column("factor")].joined(operator: .multiply)
    public static let multiply = SQLAssociativeBinaryOperator(
        sql: "*",
        neutralValue: 1.databaseValue,
        strictlyAssociative: false,
        bijective: false)
    
    /// The `AND` binary operator
    ///
    /// For example:
    ///
    ///     // isBlue AND isTall
    ///     [Column("isBlue"), Column("isTall")].joined(operator: .and)
    public static let and = SQLAssociativeBinaryOperator(
        sql: "AND",
        neutralValue: true.databaseValue,
        strictlyAssociative: true,
        bijective: false)
    
    /// The `OR` binary operator
    ///
    /// For example:
    ///
    ///     // isBlue OR isTall
    ///     [Column("isBlue"), Column("isTall")].joined(operator: .or)
    public static let or = SQLAssociativeBinaryOperator(
        sql: "OR",
        neutralValue: false.databaseValue,
        strictlyAssociative: true,
        bijective: false)
    
    /// The `||` string concatenation operator
    ///
    /// For example:
    ///
    ///     // firstName || ' ' || lastName
    ///     [Column("firstName"), " ", Column("lastName")].joined(operator: .concat)
    public static let concat = SQLAssociativeBinaryOperator(
        sql: "||",
        neutralValue: "".databaseValue,
        strictlyAssociative: true,
        bijective: true)
}

/// `SQLExpressionAssociativeBinary` is an expression made of several
/// expressions joined with an associative binary operator.
///
/// :nodoc:
struct SQLExpressionAssociativeBinary: SQLExpression {
    let expressions: [SQLExpression]
    let op: SQLAssociativeBinaryOperator
    
    /// Creates an expression made of expressions joined with an associative
    /// binary operator.
    ///
    ///     // length * width
    ///     SQLExpressionAssociativeBinary(.multiply, [Column("length"), Column("width")])
    init(_ op: SQLAssociativeBinaryOperator, _ expressions: [SQLExpression]) {
        self.op = op
        
        // flatten when possible: a • (b • c) = a • b • c
        if op.isStrictlyAssociative {
            self.expressions = expressions.flatMap { expression -> [SQLExpression] in
                if let reduce = expression as? SQLExpressionAssociativeBinary, reduce.op == op {
                    return reduce.expressions
                } else {
                    return [expression]
                }
            }
        } else {
            self.expressions = expressions
        }
    }
    
    // MARK: SQLExpression
    
    func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String? {
        switch expressions.count {
        case 0:
            return try op.neutralValue._column(db, for: alias, acceptsBijection: acceptsBijection)
        case 1:
            return try expressions[0]._column(db, for: alias, acceptsBijection: acceptsBijection)
        default:
            guard acceptsBijection && op.isBijective else {
                return nil
            }
            
            let nonConstants = expressions.filter { $0._isConstantInRequest == false }
            if nonConstants.count == 1 {
                return try nonConstants[0]._column(db, for: alias, acceptsBijection: acceptsBijection)
            }
            
            return nil
        }
    }
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        switch expressions.count {
        case 0:
            return try op.neutralValue._expressionSQL(context, wrappedInParenthesis: wrappedInParenthesis)
        case 1:
            return try expressions[0]._expressionSQL(context, wrappedInParenthesis: wrappedInParenthesis)
        default:
            let expressionSQLs = try expressions.map {
                try $0._expressionSQL(context, wrappedInParenthesis: true)
            }
            let joiner = " \(op.sql) "
            var resultSQL = expressionSQLs.joined(separator: joiner)
            
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            
            return resultSQL
        }
    }
    
    func _identifyingColums(_ db: Database, for alias: TableAlias) throws -> Set<String> {
        switch expressions.count {
        case 0:
            return try op.neutralValue._identifyingColums(db, for: alias)
        case 1:
            return try expressions[0]._identifyingColums(db, for: alias)
        default:
            if op == .and {
                return try expressions.reduce(into: []) { try $0.formUnion($1._identifyingColums(db, for: alias)) }
            } else if op == .or {
                return []
            } else {
                return []
            }
        }
    }
    
    func _identifyingRowIDs(_ db: Database, for alias: TableAlias) throws -> Set<Int64>? {
        switch expressions.count {
        case 0:
            return try op.neutralValue._identifyingRowIDs(db, for: alias)
        case 1:
            return try expressions[0]._identifyingRowIDs(db, for: alias)
        default:
            if op == .and {
                var result: Set<Int64>? = nil
                for expression in expressions {
                    if let expressionRowIDs = try expression._identifyingRowIDs(db, for: alias) {
                        if var rowIDs = result {
                            rowIDs.formIntersection(expressionRowIDs)
                            result = rowIDs
                            if rowIDs.isEmpty {
                                break
                            }
                        } else {
                            result = expressionRowIDs
                        }
                    }
                }
                return result
            } else if op == .or {
                var result: Set<Int64> = []
                for expression in expressions {
                    if let expressionRowIDs = try expression._identifyingRowIDs(db, for: alias) {
                        result.formUnion(expressionRowIDs)
                    } else {
                        return nil
                    }
                }
                return result
            } else {
                return nil
            }
        }
    }
    
    var _isConstantInRequest: Bool {
        switch expressions.count {
        case 0:
            return op.neutralValue._isConstantInRequest
        default:
            return expressions.allSatisfy(\._isConstantInRequest)
        }
    }
    
    var _isTrue: Bool {
        switch expressions.count {
        case 0:
            return op.neutralValue._isTrue
        case 1:
            return expressions[0]._isTrue
        default:
            // Could do better (1 OR x, for example)
            return false
        }
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionAssociativeBinary(op, expressions.map { $0._qualifiedExpression(with: alias) })
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool {
        switch expressions.count {
        case 0:
            return op.neutralValue._isAggregate
        default:
            return expressions.contains(where: \._isAggregate)
        }
    }
}

extension Sequence where Element == SQLExpression {
    /// Returns an expression by joining all elements with an associative SQL
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
    /// false for `.or`, and true for `.and`.
    public func joined(operator: SQLAssociativeBinaryOperator) -> SQLExpression {
        SQLExpressionAssociativeBinary(`operator`, Array(self))
    }
}

// MARK: - SQLExpressionEqual

/// :nodoc:
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
    
    // MARK: SQLExpression
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try """
            \(lhs._expressionSQL(context, wrappedInParenthesis: true)) \
            \(op.rawValue) \
            \(rhs._expressionSQL(context, wrappedInParenthesis: true))
            """
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    func _identifyingColums(_ db: Database, for alias: TableAlias) throws -> Set<String> {
        switch op {
        case .equal, .is:
            if let column = try lhs._column(db, for: alias, acceptsBijection: true),
               rhs._isConstantInRequest
            {
                return [column]
            }
            
            if let column = try rhs._column(db, for: alias, acceptsBijection: true),
               lhs._isConstantInRequest
            {
                return [column]
            }
            
            return []
            
        case .notEqual, .isNot:
            return []
        }
    }
    
    func _identifyingRowIDs(_ db: Database, for alias: TableAlias) throws -> Set<Int64>? {
        switch op {
        case .equal, .is:
            if let column = try lhs._column(db, for: alias),
               try db.columnIsRowID(column, of: alias.tableName),
               let dbValue = rhs as? DatabaseValue
            {
                if let rowID = Int64.fromDatabaseValue(dbValue) {
                    return [rowID]
                } else {
                    // We miss `rowid = '1'` here, because SQLite would interpret the '1' string as a number
                    return []
                }
            }
            
            if let column = try rhs._column(db, for: alias),
               try db.columnIsRowID(column, of: alias.tableName),
               let dbValue = lhs as? DatabaseValue
            {
                if let rowID = Int64.fromDatabaseValue(dbValue) {
                    return [rowID]
                } else {
                    // We miss `rowid = '1'` here, because SQLite would interpret the '1' string as a number
                    return []
                }
            }
            
            return nil
            
        case .notEqual, .isNot:
            return nil
        }
    }
    
    func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            return SQLExpressionEqual(op.negated, lhs, rhs)
        }
    }
    
    var _isConstantInRequest: Bool {
        lhs._isConstantInRequest && rhs._isConstantInRequest
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionEqual(op, lhs._qualifiedExpression(with: alias), rhs._qualifiedExpression(with: alias))
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool {
        lhs._isAggregate || rhs._isAggregate
    }
}

// MARK: - SQLExpressionContains

/// SQLExpressionContains is an expression that checks the inclusion of a
/// value in a collection with the `IN` operator.
///
///     // id IN (1,2,3)
///     SQLExpressionContains(Column("id"), _SQLExpressionsArray([1,2,3]))
///
/// :nodoc:
struct SQLExpressionContains: SQLExpression {
    let expression: SQLExpression
    let collection: SQLCollection
    let isNegated: Bool
    
    init(_ value: SQLExpressible, _ collection: SQLCollection, negated: Bool = false) {
        self.expression = value.sqlExpression
        self.collection = collection
        self.isNegated = negated
    }
    
    // MARK: SQLExpression
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try """
            \(expression._expressionSQL(context, wrappedInParenthesis: true)) \
            \(isNegated ? "NOT IN" : "IN") \
            \(collection._collectionSQL(context))
            """
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    func _identifyingRowIDs(_ db: Database, for alias: TableAlias) throws -> Set<Int64>? {
        if let expressions = collection._collectionExpressions,
           let column = try expression._column(db, for: alias),
           try db.columnIsRowID(column, of: alias.tableName)
        {
            return Set(expressions.compactMap {
                ($0 as? DatabaseValue).flatMap { Int64.fromDatabaseValue($0) }
            })
        } else {
            return nil
        }
    }
    
    func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            return SQLExpressionContains(expression, collection, negated: !isNegated)
        }
    }
    
    var _isConstantInRequest: Bool {
        guard let expressions = collection._collectionExpressions else {
            return false
        }
        
        return expression._isConstantInRequest && expressions.allSatisfy(\._isConstantInRequest)
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionContains(
            expression._qualifiedExpression(with: alias),
            collection._qualifiedCollection(with: alias),
            negated: isNegated)
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool {
        if expression._isAggregate {
            // SELECT aggregate IN (...)
            return true
        }
        
        if let expressions = collection._collectionExpressions,
           expressions.contains(where: \._isAggregate)
        {
            // SELECT expr IN (aggregate, ...)
            return true
        }
        
        return false
    }
}

// MARK: - SQLExpressionBetween

/// SQLExpressionBetween is an expression that checks if a values is included
/// in a range with the `BETWEEN` operator.
///
///     // id BETWEEN 1 AND 3
///     SQLExpressionBetween(Column("id"), 1.databaseValue, 3.databaseValue)
///
/// :nodoc:
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
    
    // MARK: SQLExpression
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try """
            \(expression._expressionSQL(context, wrappedInParenthesis: true)) \
            \(isNegated ? "NOT BETWEEN" : "BETWEEN") \
            \(lowerBound._expressionSQL(context, wrappedInParenthesis: true)) \
            AND \
            \(upperBound._expressionSQL(context, wrappedInParenthesis: true))
            """
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            return SQLExpressionBetween(expression, lowerBound, upperBound, negated: !isNegated)
        }
    }
    
    var _isConstantInRequest: Bool {
        expression._isConstantInRequest
            && lowerBound._isConstantInRequest
            && upperBound._isConstantInRequest
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionBetween(
            expression._qualifiedExpression(with: alias),
            lowerBound._qualifiedExpression(with: alias),
            upperBound._qualifiedExpression(with: alias),
            negated: isNegated)
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool {
        expression._isAggregate
    }
}

// MARK: - SQLExpressionFunction

/// :nodoc:
struct SQLExpressionFunction: SQLExpression {
    let function: String
    let arguments: [SQLExpression]
    
    init(_ function: String, arguments: [SQLExpression]) {
        self.function = function
        self.arguments = arguments
    }
    
    init(_ function: String, arguments: SQLExpressible...) {
        self.init(function, arguments: arguments.map(\.sqlExpression))
    }
    
    // MARK: SQLExpression
    
    func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String? {
        guard acceptsBijection else {
            return nil
        }
        let function = self.function.uppercased()
        if ["HEX", "QUOTE"].contains(function) && arguments.count == 1 {
            return try arguments[0]._column(db, for: alias, acceptsBijection: acceptsBijection)
        } else if function == "IFNULL" && arguments.count == 2 && arguments[1]._isConstantInRequest {
            return try arguments[0]._column(db, for: alias, acceptsBijection: acceptsBijection)
        } else {
            return nil
        }
    }
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        try function
            + "("
            + arguments
            .map { try $0._expressionSQL(context, wrappedInParenthesis: false) }
            .joined(separator: ", ")
            + ")"
    }
    
    private static let knownPureFunctions = [
        "ABS", "CHAR", "COALESCE", "GLOB", "HEX", "IFNULL",
        "IIF", "INSTR", "LENGTH", "LIKE", "LIKELIHOOD",
        "LIKELY", "LOAD_EXTENSION", "LOWER", "LTRIM",
        "NULLIF", "PRINTF", "QUOTE", "REPLACE", "ROUND",
        "RTRIM", "SOUNDEX", "SQLITE_COMPILEOPTION_GET",
        "SQLITE_COMPILEOPTION_USED", "SQLITE_SOURCE_ID",
        "SQLITE_VERSION", "SUBSTR", "TRIM", "TRIM",
        "TYPEOF", "UNICODE", "UNLIKELY", "UPPER", "ZEROBLOB",
    ]
    
    var _isConstantInRequest: Bool {
        let function = self.function.uppercased()
        guard ((function == "MAX" || function == "MIN") && arguments.count > 1)
                || Self.knownPureFunctions.contains(function)
        else {
            return false // Don't know - assume not constant
        }
        
        return arguments.allSatisfy(\._isConstantInRequest)
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionFunction(function, arguments: arguments.map { $0._qualifiedExpression(with: alias) })
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool {
        let function = self.function.uppercased()
        if ["MIN", "MAX"].contains(function) && arguments.count == 1 {
            return true
        } else if ["AVG", "COUNT", "SUM", "TOTAL"].contains(function) && arguments.count == 1 {
            return true
        } else if function == "GROUP_CONCAT" && (arguments.count == 1 || arguments.count == 2) {
            return true
        } else {
            return false
        }
    }
}

// MARK: - SQLExpressionCount

/// SQLExpressionCount is a call to the SQL `COUNT` function.
///
///     // COUNT(name)
///     SQLExpressionCount(Column("name"))
///
/// :nodoc:
struct SQLExpressionCount: SQLExpression {
    /// The counted value
    let counted: SQLSelectable
    
    init(_ counted: SQLSelectable) {
        self.counted = counted
    }
    
    // MARK: SQLExpression
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        try "COUNT(\(counted._countedSQL(context)))"
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionCount(counted._qualifiedSelectable(with: alias))
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool { true }
}

// MARK: - SQLExpressionCountDistinct

/// SQLExpressionCountDistinct is a call to the SQL `COUNT(DISTINCT ...)` function.
///
///     // COUNT(DISTINCT name)
///     SQLExpressionCountDistinct(Column("name"))
///
/// :nodoc:
struct SQLExpressionCountDistinct: SQLExpression {
    let counted: SQLExpression
    
    init(_ counted: SQLExpression) {
        self.counted = counted
    }
    
    // MARK: SQLExpression
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        try "COUNT(DISTINCT \(counted._countedSQL(context)))"
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionCountDistinct(counted._qualifiedExpression(with: alias))
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool { true }
}

// MARK: - SQLExpressionIsEmpty

/// This one helps generating `COUNT(...) = 0` or `COUNT(...) > 0` while letting
/// the user using the not `!` logical operator, or comparisons with booleans
/// such as `== true` or `== false`.
///
/// :nodoc:
struct SQLExpressionIsEmpty: SQLExpression {
    var countExpression: SQLExpression
    var isEmpty: Bool
    
    // countExpression should be a counting expression
    init(_ countExpression: SQLExpression, isEmpty: Bool = true) {
        self.countExpression = countExpression
        self.isEmpty = isEmpty
    }
    
    // MARK: SQLExpression
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try """
            \(countExpression._expressionSQL(context, wrappedInParenthesis: true)) \
            \(isEmpty ? "= 0" : "> 0")
            """
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return self
        case .false, .falsey:
            return SQLExpressionIsEmpty(countExpression, isEmpty: !isEmpty)
        }
    }
    
    var _isConstantInRequest: Bool { countExpression._isConstantInRequest }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionIsEmpty(countExpression._qualifiedExpression(with: alias), isEmpty: isEmpty)
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool { countExpression._isAggregate }
}

// MARK: - SQLExpressionTableMatch

/// :nodoc:
struct SQLExpressionTableMatch: SQLExpression {
    var alias: TableAlias
    var pattern: SQLExpression
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try """
            \(context.resolvedName(for: alias).quotedDatabaseIdentifier) \
            MATCH \
            \(pattern._expressionSQL(context, wrappedInParenthesis: true))
            """
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionTableMatch(
            alias: self.alias,
            pattern: pattern._qualifiedExpression(with: alias))
    }
}

// MARK: - SQLExpressionCollate

/// SQLExpressionCollate is an expression tainted by an SQLite collation.
///
///     // email = 'arthur@example.com' COLLATE NOCASE
///     SQLExpressionCollate(Column("email") == "arthur@example.com", "NOCASE")
///
/// :nodoc:
struct SQLExpressionCollate: SQLExpression {
    let expression: SQLExpression
    let collationName: Database.CollationName
    
    init(_ expression: SQLExpression, collationName: Database.CollationName) {
        self.expression = expression
        self.collationName = collationName
    }
    
    // MARK: SQLExpression
    
    func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String? {
        try expression._column(db, for: alias, acceptsBijection: acceptsBijection)
    }
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var resultSQL = try """
            \(expression._expressionSQL(context, wrappedInParenthesis: false)) \
            COLLATE \
            \(collationName.rawValue)
            """
        
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
        
        return resultSQL
    }
    
    func _identifyingColums(_ db: Database, for alias: TableAlias) throws -> Set<String> {
        try expression._identifyingColums(db, for: alias)
    }
    
    func _identifyingRowIDs(_ db: Database, for alias: TableAlias) throws -> Set<Int64>? {
        try expression._identifyingRowIDs(db, for: alias)
    }
    
    func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        SQLExpressionCollate(expression._is(test), collationName: collationName)
    }
    
    var _isConstantInRequest: Bool { expression._isConstantInRequest }
    
    var _isTrue: Bool { expression._isTrue }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionCollate(expression._qualifiedExpression(with: alias), collationName: collationName)
    }
    
    // MARK: SQLSelectable
    
    var _isAggregate: Bool { expression._isAggregate }
    
}

// MARK: - SQLExpressionFastPrimaryKey

/// SQLExpressionFastPrimaryKey is an expression that picks the fastest available
/// primary key.
///
/// It crashes for WITHOUT ROWID table with a multi-columns primary key.
/// Future versions of GRDB may use [row values](https://www.sqlite.org/rowvalue.html).
///
/// :nodoc:
struct SQLExpressionFastPrimaryKey: SQLExpression {
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        // Likely a GRDB bug: how comes this expression is used before it
        // has been qualified?
        fatalError("SQLExpressionFastPrimaryKey is not qualified.")
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLExpressionQualifiedFastPrimaryKey(alias: alias)
    }
}

/// :nodoc:
struct SQLExpressionQualifiedFastPrimaryKey: SQLExpression {
    let alias: TableAlias
    
    /// Return the name of the fast primary key column
    func columnName(_ db: Database) throws -> String {
        let primaryKey = try db.primaryKey(alias.tableName)
        if let rowIDColumn = primaryKey.rowIDColumn {
            // Prefer the user-provided name of the rowid
            return rowIDColumn
        } else if primaryKey.tableHasRowID {
            // Prefer the rowid
            return Column.rowID.name
        } else if primaryKey.columns.count == 1 {
            // WITHOUT ROWID table: use primary key column
            return primaryKey.columns[0]
        } else {
            fatalError("Not implemented: WITHOUT ROWID table with a multi-columns primary key")
        }
    }
    
    func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String? {
        if alias == self.alias {
            return try columnName(db)
        }
        return nil
    }
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        try SQLQualifiedColumn(columnName(context.db), alias: alias)
            ._expressionSQL(context, wrappedInParenthesis: wrappedInParenthesis)
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        // Never requalify
        self
    }
}
