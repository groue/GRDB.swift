// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

// Outputs "x = y" or "x IS NULL"
private func isEqual(_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLExpression {
    switch (lhs, rhs) {
    case let (lhs, rhs as DatabaseValue):
        switch rhs.storage {
        case .null:
            return SQLExpressionEqual(.is, lhs, rhs)
        default:
            return SQLExpressionEqual(.equal, lhs, rhs)
        }
    case let (lhs as DatabaseValue, rhs):
        switch lhs.storage {
        case .null:
            return SQLExpressionEqual(.is, rhs, lhs)
        default:
            return SQLExpressionEqual(.equal, lhs, rhs)
        }
    default:
        return SQLExpressionEqual(.equal, lhs, rhs)
    }
}

/// An SQL expression that compares two expressions with the `=` SQL operator.
///
///     // name = 'Arthur'
///     Column("name") == "Arthur"
///
/// When the right operand is nil, `IS NULL` is used instead.
///
///     // name IS NULL
///     Column("name") == nil
public func == (lhs: SQLSpecificExpressible, rhs: SQLExpressible?) -> SQLExpression {
    return isEqual(lhs.sqlExpression, rhs?.sqlExpression ?? DatabaseValue.null)
}

/// An SQL expression that compares two expressions with the `=` SQL operator.
///
///     // name = 'Arthur' COLLATE NOCASE
///     Column("name").collating(.nocase) == "Arthur"
///
/// When the right operand is nil, `IS NULL` is used instead.
///
///     // name IS NULL
///     Column("name").collating(.nocase) == nil
public func == (lhs: SQLCollatedExpression, rhs: SQLExpressible?) -> SQLExpression {
    return SQLExpressionCollate(lhs.expression == rhs, collationName: lhs.collationName)
}

/// An SQL expression that checks the boolean value of an expression.
///
/// The comparison is done with the built-in boolean evaluation of SQLite:
///
///     // validated
///     Column("validated") == true
///
///     // NOT validated
///     Column("validated") == false
public func == (lhs: SQLSpecificExpressible, rhs: Bool) -> SQLExpression {
    if rhs {
        return lhs.sqlExpression
    } else {
        return lhs.sqlExpression.negated
    }
}

/// An SQL expression that compares two expressions with the `=` SQL operator.
///
///     // 'Arthur' = name
///     "Arthur" == Column("name")
///
/// When the left operand is nil, `IS NULL` is used instead.
///
///     // name IS NULL
///     nil == Column("name")
public func == (lhs: SQLExpressible?, rhs: SQLSpecificExpressible) -> SQLExpression {
    return isEqual(lhs?.sqlExpression ?? DatabaseValue.null, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `=` SQL operator.
///
///     // 'Arthur' = name COLLATE NOCASE
///     "Arthur" == Column("name").collating(.nocase)
///
/// When the left operand is nil, `IS NULL` is used instead.
///
///     // name IS NULL
///     nil == Column("name").collating(.nocase)
public func == (lhs: SQLExpressible?, rhs: SQLCollatedExpression) -> SQLExpression {
    return SQLExpressionCollate(lhs == rhs.expression, collationName: rhs.collationName)
}

/// An SQL expression that checks the boolean value of an expression.
///
/// The comparison is done with the built-in boolean evaluation of SQLite:
///
///     // validated
///     true == Column("validated")
///
///     // NOT validated
///     false == Column("validated")
public func == (lhs: Bool, rhs: SQLSpecificExpressible) -> SQLExpression {
    if lhs {
        return rhs.sqlExpression
    } else {
        return rhs.sqlExpression.negated
    }
}

/// An SQL expression that compares two expressions with the `=` SQL operator.
///
///     // email = login
///     Column("email") == Column("login")
public func == (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return isEqual(lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<>` SQL operator.
///
///     // name <> 'Arthur'
///     Column("name") != "Arthur"
///
/// When the right operand is nil, `IS NOT NULL` is used instead.
///
///     // name IS NOT NULL
///     Column("name") != nil
public func != (lhs: SQLSpecificExpressible, rhs: SQLExpressible?) -> SQLExpression {
    return isEqual(lhs.sqlExpression, rhs?.sqlExpression ?? DatabaseValue.null).negated
}

/// An SQL expression that compares two expressions with the `<>` SQL operator.
///
///     // name <> 'Arthur' COLLATE NOCASE
///     Column("name").collating(.nocase) != "Arthur"
///
/// When the right operand is nil, `IS NOT NULL` is used instead.
///
///     // name IS NOT NULL
///     Column("name").collating(.nocase) != nil
public func != (lhs: SQLCollatedExpression, rhs: SQLExpressible?) -> SQLExpression {
    return SQLExpressionCollate(lhs.expression != rhs, collationName: lhs.collationName)
}

/// An SQL expression that checks the boolean value of an expression.
///
/// The comparison is done with the built-in boolean evaluation of SQLite:
///
///     // NOT validated
///     Column("validated") != true
///
///     // validated
///     Column("validated") != false
public func != (lhs: SQLSpecificExpressible, rhs: Bool) -> SQLExpression {
    if rhs {
        return lhs.sqlExpression.negated
    } else {
        return lhs.sqlExpression
    }
}

/// An SQL expression that compares two expressions with the `<>` SQL operator.
///
///     // 'Arthur' <> name
///     "Arthur" != Column("name")
///
/// When the left operand is nil, `IS NOT NULL` is used instead.
///
///     // name IS NOT NULL
///     nil != Column("name")
public func != (lhs: SQLExpressible?, rhs: SQLSpecificExpressible) -> SQLExpression {
    return isEqual(lhs?.sqlExpression ?? DatabaseValue.null, rhs.sqlExpression).negated
}

/// An SQL expression that compares two expressions with the `<>` SQL operator.
///
///     // 'Arthur' <> name COLLATE NOCASE
///     "Arthur" != Column("name").collating(.nocase)
///
/// When the left operand is nil, `IS NOT NULL` is used instead.
///
///     // name IS NOT NULL
///     nil != Column("name").collating(.nocase)
public func != (lhs: SQLExpressible?, rhs: SQLCollatedExpression) -> SQLExpression {
    return SQLExpressionCollate(lhs != rhs.expression, collationName: rhs.collationName)
}

/// An SQL expression that checks the boolean value of an expression.
///
/// The comparison is done with the built-in boolean evaluation of SQLite:
///
///     // NOT validated
///     true != Column("validated")
///
///     // validated
///     false != Column("validated")
public func != (lhs: Bool, rhs: SQLSpecificExpressible) -> SQLExpression {
    if lhs {
        return rhs.sqlExpression.negated
    } else {
        return rhs.sqlExpression
    }
}

/// An SQL expression that compares two expressions with the `<>` SQL operator.
///
///     // email <> login
///     Column("email") != Column("login")
public func != (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return isEqual(lhs.sqlExpression, rhs.sqlExpression).negated
}

/// An SQL expression that compares two expressions with the `IS` SQL operator.
///
///     // name IS 'Arthur'
///     Column("name") === "Arthur"
public func === (lhs: SQLSpecificExpressible, rhs: SQLExpressible?) -> SQLExpression {
    return SQLExpressionEqual(.is, lhs.sqlExpression, rhs?.sqlExpression ?? DatabaseValue.null)
}

/// An SQL expression that compares two expressions with the `IS` SQL operator.
///
///     // name IS 'Arthur' COLLATE NOCASE
///     Column("name").collating(.nocase) === "Arthur"
public func === (lhs: SQLCollatedExpression, rhs: SQLExpressible?) -> SQLExpression {
    return SQLExpressionCollate(lhs.expression === rhs, collationName: lhs.collationName)
}

/// An SQL expression that compares two expressions with the `IS` SQL operator.
///
///     // name IS 'Arthur'
///     "Arthur" === Column("name")
public func === (lhs: SQLExpressible?, rhs: SQLSpecificExpressible) -> SQLExpression {
    if let lhs = lhs {
        return SQLExpressionEqual(.is, lhs.sqlExpression, rhs.sqlExpression)
    } else {
        return SQLExpressionEqual(.is, rhs.sqlExpression, DatabaseValue.null)
    }
}

/// An SQL expression that compares two expressions with the `IS` SQL operator.
///
///     // name IS 'Arthur' COLLATE NOCASE
///     "Arthur" === Column("name").collating(.nocase)
public func === (lhs: SQLExpressible?, rhs: SQLCollatedExpression) -> SQLExpression {
    return SQLExpressionCollate(lhs === rhs.expression, collationName: rhs.collationName)
}

/// An SQL expression that compares two expressions with the `IS` SQL operator.
///
///     // email IS login
///     Column("email") === Column("login")
public func === (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionEqual(.is, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // name IS NOT 'Arthur'
///     Column("name") !== "Arthur"
public func !== (lhs: SQLSpecificExpressible, rhs: SQLExpressible?) -> SQLExpression {
    return SQLExpressionEqual(.isNot, lhs.sqlExpression, rhs?.sqlExpression ?? DatabaseValue.null)
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // name IS NOT 'Arthur' COLLATE NOCASE
///     Column("name").collating(.nocase) !== "Arthur"
public func !== (lhs: SQLCollatedExpression, rhs: SQLExpressible?) -> SQLExpression {
    return SQLExpressionCollate(lhs.expression !== rhs, collationName: lhs.collationName)
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // name IS NOT 'Arthur'
///     "Arthur" !== Column("name")
public func !== (lhs: SQLExpressible?, rhs: SQLSpecificExpressible) -> SQLExpression {
    if let lhs = lhs {
        return SQLExpressionEqual(.isNot, lhs.sqlExpression, rhs.sqlExpression)
    } else {
        return SQLExpressionEqual(.isNot, rhs.sqlExpression, DatabaseValue.null)
    }
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // name IS NOT 'Arthur' COLLATE NOCASE
///     "Arthur" !== Column("name").collating(.nocase)
public func !== (lhs: SQLExpressible?, rhs: SQLCollatedExpression) -> SQLExpression {
    return SQLExpressionCollate(lhs !== rhs.expression, collationName: rhs.collationName)
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // email IS NOT login
///     Column("email") !== Column("login")
public func !== (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionEqual(.isNot, lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Comparison Operators (<, >, <=, >=)

extension SQLBinaryOperator {
    /// The `<` binary operator
    static let lessThan = SQLBinaryOperator("<")
    
    /// The `<=` binary operator
    static let lessThanOrEqual = SQLBinaryOperator("<=")
    
    /// The `>` binary operator
    static let greaterThan = SQLBinaryOperator(">")
    
    /// The `>=` binary operator
    static let greaterThanOrEqual = SQLBinaryOperator(">=")
}

/// An SQL expression that compares two expressions with the `<` SQL operator.
///
///     // score < 18
///     Column("score") < 18
public func < (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<` SQL operator.
///
///     // name < 'Arthur' COLLATE NOCASE
///     Column("name").collating(.nocase) < "Arthur"
public func < (lhs: SQLCollatedExpression, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionCollate(lhs.expression < rhs, collationName: lhs.collationName)
}

/// An SQL expression that compares two expressions with the `<` SQL operator.
///
///     // 18 < score
///     18 < Column("score")
public func < (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<` SQL operator.
///
///     // 'Arthur' < name COLLATE NOCASE
///     "Arthur" < Column("name").collating(.nocase)
public func < (lhs: SQLExpressible, rhs: SQLCollatedExpression) -> SQLExpression {
    return SQLExpressionCollate(lhs < rhs.expression, collationName: rhs.collationName)
}

/// An SQL expression that compares two expressions with the `<` SQL operator.
///
///     // width < height
///     Column("width") < Column("height")
public func < (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<=` SQL operator.
///
///     // score <= 18
///     Column("score") <= 18
public func <= (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<=` SQL operator.
///
///     // name <= 'Arthur' COLLATE NOCASE
///     Column("name").collating(.nocase) <= "Arthur"
public func <= (lhs: SQLCollatedExpression, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionCollate(lhs.expression <= rhs, collationName: lhs.collationName)
}

/// An SQL expression that compares two expressions with the `<=` SQL operator.
///
///     // 18 <= score
///     18 <= Column("score")
public func <= (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<=` SQL operator.
///
///     // 'Arthur' <= name COLLATE NOCASE
///     "Arthur" <= Column("name").collating(.nocase)
public func <= (lhs: SQLExpressible, rhs: SQLCollatedExpression) -> SQLExpression {
    return SQLExpressionCollate(lhs <= rhs.expression, collationName: rhs.collationName)
}

/// An SQL expression that compares two expressions with the `<=` SQL operator.
///
///     // width <= height
///     Column("width") <= Column("height")
public func <= (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>` SQL operator.
///
///     // score > 18
///     Column("score") > 18
public func > (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>` SQL operator.
///
///     // name > 'Arthur' COLLATE NOCASE
///     Column("name").collating(.nocase) > "Arthur"
public func > (lhs: SQLCollatedExpression, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionCollate(lhs.expression > rhs, collationName: lhs.collationName)
}

/// An SQL expression that compares two expressions with the `>` SQL operator.
///
///     // 18 > score
///     18 > Column("score")
public func > (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>` SQL operator.
///
///     // 'Arthur' > name COLLATE NOCASE
///     "Arthur" > Column("name").collating(.nocase)
public func > (lhs: SQLExpressible, rhs: SQLCollatedExpression) -> SQLExpression {
    return SQLExpressionCollate(lhs > rhs.expression, collationName: rhs.collationName)
}

/// An SQL expression that compares two expressions with the `>` SQL operator.
///
///     // width > height
///     Column("width") > Column("height")
public func > (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>=` SQL operator.
///
///     // score >= 18
///     Column("score") >= 18
public func >= (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>=` SQL operator.
///
///     // name >= 'Arthur' COLLATE NOCASE
///     Column("name").collating(.nocase) >= "Arthur"
public func >= (lhs: SQLCollatedExpression, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionCollate(lhs.expression >= rhs, collationName: lhs.collationName)
}

/// An SQL expression that compares two expressions with the `>=` SQL operator.
///
///     // 18 >= score
///     18 >= Column("score")
public func >= (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>=` SQL operator.
///
///     // 'Arthur' >= name COLLATE NOCASE
///     "Arthur" >= Column("name").collating(.nocase)
public func >= (lhs: SQLExpressible, rhs: SQLCollatedExpression) -> SQLExpression {
    return SQLExpressionCollate(lhs >= rhs.expression, collationName: rhs.collationName)
}

/// An SQL expression that compares two expressions with the `>=` SQL operator.
///
///     // width >= height
///     Column("width") >= Column("height")
public func >= (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Inclusion Operators (BETWEEN, IN)

extension Range where Bound: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // email >= 'A' AND email < 'B'
    ///     ("A"..<"B").contains(Column("email"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        return (element >= lowerBound) && (element < upperBound)
    }
    
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // email >= 'A' COLLATE NOCASE AND email < 'B' COLLATE NOCASE
    ///     ("A"..<"B").contains(Column("email").collating(.nocase))
    public func contains(_ element: SQLCollatedExpression) -> SQLExpression {
        return (element >= lowerBound) && (element < upperBound)
    }
}

extension ClosedRange where Bound: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // email BETWEEN 'A' AND 'B'
    ///     ("A"..."B").contains(Column("email"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        return SQLExpressionBetween(element.sqlExpression, lowerBound.sqlExpression, upperBound.sqlExpression)
    }
    
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // email BETWEEN 'A' AND 'B' COLLATE NOCASE
    ///     ("A"..."B").contains(Column("email").collating(.nocase))
    public func contains(_ element: SQLCollatedExpression) -> SQLExpression {
        return SQLExpressionCollate(contains(element.expression), collationName: element.collationName)
    }
}

extension CountableRange where Bound: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // id BETWEEN 1 AND 9
    ///     (1..<10).contains(Column("id"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        return (element >= lowerBound) && (element < upperBound)
    }
}

extension CountableClosedRange where Bound: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // id BETWEEN 1 AND 10
    ///     (1...10).contains(Column("id"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        return SQLExpressionBetween(element.sqlExpression, lowerBound.sqlExpression, upperBound.sqlExpression)
    }
}

extension Sequence where Self.Iterator.Element: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in
    /// a sequence.
    ///
    ///     // id IN (1,2,3)
    ///     [1, 2, 3].contains(Column("id"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        return SQLExpressionsArray(self).contains(element.sqlExpression)
    }
    
    /// An SQL expression that checks the inclusion of an expression in
    /// a sequence.
    ///
    ///     // name IN ('A', 'B') COLLATE NOCASE
    ///     ["A", "B"].contains(Column("name").collating(.nocase))
    public func contains(_ element: SQLCollatedExpression) -> SQLExpression {
        return SQLExpressionCollate(contains(element.expression), collationName: element.collationName)
    }
}


// MARK: - Arithmetic Operators (+, -, *, /)

extension SQLBinaryOperator {
    /// The `-` binary operator
    static let subtract = SQLBinaryOperator("-")
    
    /// The `/` binary operator
    static let divide = SQLBinaryOperator("/")
}

extension SQLAssociativeBinaryOperator {
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
}

extension SQLUnaryOperator {
    /// The `-` unary operator
    static let minus = SQLUnaryOperator("-", needsRightSpace: false)
}

/// An SQL arithmetic multiplication.
///
///     // width * 2
///     Column("width") * 2
public func * (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic multiplication.
///
///     // 2 * width
///     2 * Column("width")
public func * (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic multiplication.
///
///     // width * height
///     Column("width") * Column("height")
public func * (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic division.
///
///     // width / 2
///     Column("width") / 2
public func / (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.divide, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic division.
///
///     // 2 / width
///     2 / Column("width")
public func / (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.divide, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic division.
///
///     // width / height
///     Column("width") / Column("height")
public func / (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.divide, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic addition.
///
///     // width + 2
///     Column("width") + 2
public func + (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.add, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic addition.
///
///     // 2 + width
///     2 + Column("width")
public func + (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.add, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic addition.
///
///     // width + height
///     Column("width") + Column("height")
public func + (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.add, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A negated SQL arithmetic expression.
///
///     // -width
///     -Column("width")
public prefix func - (value: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionUnary(.minus, value.sqlExpression)
}

/// An SQL arithmetic substraction.
///
///     // width - 2
///     Column("width") - 2
public func - (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic substraction.
///
///     // 2 - width
///     2 - Column("width")
public func - (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic substraction.
///
///     // width - height
///     Column("width") - Column("height")
public func - (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Logical Operators (AND, OR, NOT)

extension SQLAssociativeBinaryOperator {
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
}

/// A logical SQL expression with the `AND` SQL operator.
///
///     // favorite AND 0
///     Column("favorite") && false
public func && (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.and, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `AND` SQL operator.
///
///     // 0 AND favorite
///     false && Column("favorite")
public func && (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.and, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `AND` SQL operator.
///
///     // email IS NOT NULL AND favorite
///     Column("email") != nil && Column("favorite")
public func && (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.and, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // favorite OR 1
///     Column("favorite") || true
public func || (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.or, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // 0 OR favorite
///     true || Column("favorite")
public func || (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.or, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // email IS NULL OR hidden
///     Column("email") == nil || Column("hidden")
public func || (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinaryReduce(.or, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A negated logical SQL expression with the `NOT` SQL operator.
///
///     // NOT hidden
///     !Column("hidden")
///
/// Some expressions may be negated with specific SQL operators:
///
///     // id NOT BETWEEN 1 AND 10
///     !((1...10).contains(Column("id")))
public prefix func ! (value: SQLSpecificExpressible) -> SQLExpression {
    return value.sqlExpression.negated
}

// MARK: - Like Operator

extension SQLBinaryOperator {
    /// The `LIKE` binary operator
    static let like = SQLBinaryOperator("LIKE")
}

/// :nodoc:
extension SQLSpecificExpressible {
    
    /// An SQL expression with the `LIKE` SQL operator.
    ///
    ///     // email LIKE '%@example.com"
    ///     Column("email").like("%@example.com")
    public func like(_ pattern: SQLExpressible) -> SQLExpression {
        return SQLExpressionBinary(.like, self, pattern)
    }
}

// MARK: - Concat Operator

extension SQLAssociativeBinaryOperator {
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

// MARK: - Match Operator

extension SQLBinaryOperator {
    /// The `MATCH` binary operator
    static let match = SQLBinaryOperator("MATCH")
}
