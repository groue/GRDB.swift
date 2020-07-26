// MARK: - SQLExpression

extension SQLExpression {
    /// The expression as a quoted SQL literal (not public in order to avoid abuses)
    ///
    ///     try "foo'bar".databaseValue.quotedSQL(db) // "'foo''bar'""
    func quotedSQL(_ db: Database) throws -> String {
        let context = SQLGenerationContext(db, argumentsSink: .forRawSQL)
        return try expressionSQL(context, wrappedInParenthesis: false)
    }
}

// MARK: - _SQLExpressionNot

/// :nodoc:
public struct _SQLExpressionNot: SQLExpression {
    let expression: SQLExpression
    
    init(_ expression: SQLExpression) {
        self.expression = expression
    }
    
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return _SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return _SQLExpressionEqual(.equal, self, false.sqlExpression)
        
        case .falsey:
            // Support `NOT (NOT expression)` as a technique to build 0 or 1
            return _SQLExpressionNot(self)
        }
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionNot(expression._qualifiedExpression(with: alias))
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionUnary

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

/// _SQLExpressionUnary is an expression made of an unary operator and
/// an operand expression.
///
/// :nodoc:
public struct _SQLExpressionUnary: SQLExpression {
    let op: SQLUnaryOperator
    let expression: SQLExpression
    
    init(_ op: SQLUnaryOperator, _ value: SQLExpressible) {
        self.op = op
        self.expression = value.sqlExpression
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionUnary(op, expression._qualifiedExpression(with: alias))
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionBinary

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

/// _SQLExpressionBinary is an expression made of two expressions joined with a
/// binary operator.
///
///     _SQLExpressionBinary(.multiply, Column("length"), Column("width"))
///
/// :nodoc:
public struct _SQLExpressionBinary: SQLExpression {
    let lhs: SQLExpression
    let op: SQLBinaryOperator
    let rhs: SQLExpression
    
    /// Creates an expression made of two expressions joined with a
    /// binary operator.
    ///
    ///     // length * width
    ///     _SQLExpressionBinary(.subtract, Column("score"), Column("malus"))
    init(_ op: SQLBinaryOperator, _ lhs: SQLExpressible, _ rhs: SQLExpressible) {
        self.lhs = lhs.sqlExpression
        self.op = op
        self.rhs = rhs.sqlExpression
    }
    
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return _SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return _SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            if let negatedOp = op.negated {
                return _SQLExpressionBinary(negatedOp, lhs, rhs)
            } else {
                return _SQLExpressionNot(self)
            }
        }
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionBinary(op, lhs._qualifiedExpression(with: alias), rhs._qualifiedExpression(with: alias))
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionAssociativeBinary

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
    
    /// if true, (a • b) • c is strictly equal to a • (b • c).
    ///
    /// `AND`, `OR`, `||` (concat) are stricly associative.
    ///
    /// `+` and `*` are not stricly associative when applied to floating
    /// point values.
    let strictlyAssociative: Bool
    
    /// Creates a binary operator
    init(sql: String, neutralValue: DatabaseValue, strictlyAssociative: Bool) {
        self.sql = sql
        self.neutralValue = neutralValue
        self.strictlyAssociative = strictlyAssociative
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
        strictlyAssociative: false)
    
    /// The `*` binary operator
    ///
    /// For example:
    ///
    ///     // score * factor
    ///     [Column("score"), Column("factor")].joined(operator: .multiply)
    public static let multiply = SQLAssociativeBinaryOperator(
        sql: "*",
        neutralValue: 1.databaseValue,
        strictlyAssociative: false)
    
    /// The `AND` binary operator
    ///
    /// For example:
    ///
    ///     // isBlue AND isTall
    ///     [Column("isBlue"), Column("isTall")].joined(operator: .and)
    public static let and = SQLAssociativeBinaryOperator(
        sql: "AND",
        neutralValue: true.databaseValue,
        strictlyAssociative: true)
    
    /// The `OR` binary operator
    ///
    /// For example:
    ///
    ///     // isBlue OR isTall
    ///     [Column("isBlue"), Column("isTall")].joined(operator: .or)
    public static let or = SQLAssociativeBinaryOperator(
        sql: "OR",
        neutralValue: false.databaseValue,
        strictlyAssociative: true)
    
    /// The `||` string concatenation operator
    ///
    /// For example:
    ///
    ///     // firstName || ' ' || lastName
    ///     [Column("firstName"), " ", Column("lastName")].joined(operator: .concat)
    public static let concat = SQLAssociativeBinaryOperator(
        sql: "||",
        neutralValue: "".databaseValue,
        strictlyAssociative: true)
}

/// `_SQLExpressionAssociativeBinary` is an expression made of several
/// expressions joined with an associative binary operator.
///
/// :nodoc:
public struct _SQLExpressionAssociativeBinary: SQLExpression {
    let expressions: [SQLExpression]
    let op: SQLAssociativeBinaryOperator
    
    /// Creates an expression made of expressions joined with an associative
    /// binary operator.
    ///
    ///     // length * width
    ///     _SQLExpressionAssociativeBinary(.multiply, [Column("length"), Column("width")])
    init(_ op: SQLAssociativeBinaryOperator, _ expressions: [SQLExpression]) {
        self.op = op
        
        // flatten when possible: a • (b • c) = a • b • c
        if op.strictlyAssociative {
            self.expressions = expressions.flatMap { expression -> [SQLExpression] in
                if let reduce = expression as? _SQLExpressionAssociativeBinary, reduce.op == op {
                    return reduce.expressions
                } else {
                    return [expression]
                }
            }
        } else {
            self.expressions = expressions
        }
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionAssociativeBinary(op, expressions.map { $0._qualifiedExpression(with: alias) })
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        switch expressions.count {
        case 0:
            try op.neutralValue._accept(&visitor)
        case 1:
            try expressions[0]._accept(&visitor)
        default:
            try visitor.visit(self)
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
        _SQLExpressionAssociativeBinary(`operator`, Array(self))
    }
}

// MARK: - _SQLExpressionEqual

/// :nodoc:
public struct _SQLExpressionEqual: SQLExpression {
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
    
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return _SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return _SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            return _SQLExpressionEqual(op.negated, lhs, rhs)
        }
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionEqual(op, lhs._qualifiedExpression(with: alias), rhs._qualifiedExpression(with: alias))
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionContains

/// _SQLExpressionContains is an expression that checks the inclusion of a
/// value in a collection with the `IN` operator.
///
///     // id IN (1,2,3)
///     _SQLExpressionContains(Column("id"), _SQLExpressionsArray([1,2,3]))
///
/// :nodoc:
public struct _SQLExpressionContains: SQLExpression {
    let expression: SQLExpression
    let collection: SQLCollection
    let isNegated: Bool
    
    init(_ value: SQLExpressible, _ collection: SQLCollection, negated: Bool = false) {
        self.expression = value.sqlExpression
        self.collection = collection
        self.isNegated = negated
    }
    
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return _SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return _SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            return _SQLExpressionContains(expression, collection, negated: !isNegated)
        }
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionContains(
            expression._qualifiedExpression(with: alias),
            collection._qualifiedCollection(with: alias),
            negated: isNegated)
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionBetween

/// _SQLExpressionBetween is an expression that checks if a values is included
/// in a range with the `BETWEEN` operator.
///
///     // id BETWEEN 1 AND 3
///     _SQLExpressionBetween(Column("id"), 1.databaseValue, 3.databaseValue)
///
/// :nodoc:
public struct _SQLExpressionBetween: SQLExpression {
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
    
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return _SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return _SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            return _SQLExpressionBetween(expression, lowerBound, upperBound, negated: !isNegated)
        }
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionBetween(
            expression._qualifiedExpression(with: alias),
            lowerBound._qualifiedExpression(with: alias),
            upperBound._qualifiedExpression(with: alias),
            negated: isNegated)
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionFunction

/// :nodoc:
public struct _SQLExpressionFunction: SQLExpression {
    let function: String
    let arguments: [SQLExpression]
    
    init(_ function: String, arguments: [SQLExpression]) {
        self.function = function
        self.arguments = arguments
    }
    
    init(_ function: String, arguments: SQLExpressible...) {
        self.init(function, arguments: arguments.map(\.sqlExpression))
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionFunction(function, arguments: arguments.map { $0._qualifiedExpression(with: alias) })
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionCount

/// _SQLExpressionCount is a call to the SQL `COUNT` function.
///
///     // COUNT(name)
///     _SQLExpressionCount(Column("name"))
///
/// :nodoc:
public struct _SQLExpressionCount: SQLExpression {
    /// The counted value
    let counted: SQLSelectable
    
    init(_ counted: SQLSelectable) {
        self.counted = counted
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionCount(counted._qualifiedSelectable(with: alias))
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionCountDistinct

/// _SQLExpressionCountDistinct is a call to the SQL `COUNT(DISTINCT ...)` function.
///
///     // COUNT(DISTINCT name)
///     _SQLExpressionCountDistinct(Column("name"))
///
/// :nodoc:
public struct _SQLExpressionCountDistinct: SQLExpression {
    let counted: SQLExpression
    
    init(_ counted: SQLExpression) {
        self.counted = counted
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionCountDistinct(counted._qualifiedExpression(with: alias))
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionIsEmpty

/// This one helps generating `COUNT(...) = 0` or `COUNT(...) > 0` while letting
/// the user using the not `!` logical operator, or comparisons with booleans
/// such as `== true` or `== false`.
///
/// :nodoc:
public struct _SQLExpressionIsEmpty: SQLExpression {
    var countExpression: SQLExpression
    var isEmpty: Bool
    
    // countExpression should be a counting expression
    init(_ countExpression: SQLExpression, isEmpty: Bool = true) {
        self.countExpression = countExpression
        self.isEmpty = isEmpty
    }
    
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return self
        case .false, .falsey:
            return _SQLExpressionIsEmpty(countExpression, isEmpty: !isEmpty)
        }
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionIsEmpty(countExpression._qualifiedExpression(with: alias), isEmpty: isEmpty)
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionTableMatch

/// :nodoc:
public struct _SQLExpressionTableMatch: SQLExpression {
    var alias: TableAlias
    var pattern: SQLExpression
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionTableMatch(
            alias: self.alias,
            pattern: pattern._qualifiedExpression(with: alias))
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionCollate

/// _SQLExpressionCollate is an expression tainted by an SQLite collation.
///
///     // email = 'arthur@example.com' COLLATE NOCASE
///     _SQLExpressionCollate(Column("email") == "arthur@example.com", "NOCASE")
///
/// :nodoc:
public struct _SQLExpressionCollate: SQLExpression {
    let expression: SQLExpression
    let collationName: Database.CollationName
    
    init(_ expression: SQLExpression, collationName: Database.CollationName) {
        self.expression = expression
        self.collationName = collationName
    }
    
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        _SQLExpressionCollate(expression._is(test), collationName: collationName)
    }
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionCollate(expression._qualifiedExpression(with: alias), collationName: collationName)
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLExpressionFastPrimaryKey

/// _SQLExpressionFastPrimaryKey is an expression that picks the fastest available
/// primary key.
///
/// It crashes for WITHOUT ROWID table with a multi-columns primary key.
/// Future versions of GRDB may use [row values](https://www.sqlite.org/rowvalue.html).
///
/// :nodoc:
public struct _SQLExpressionFastPrimaryKey: SQLExpression {
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLExpressionQualifiedFastPrimaryKey(alias: alias)
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

/// :nodoc:
public struct _SQLExpressionQualifiedFastPrimaryKey: SQLExpression {
    let alias: TableAlias
    
    /// :nodoc:
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        // Never requalify
        self
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
    
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
}
