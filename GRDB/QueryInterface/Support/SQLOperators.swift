// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

extension SQLBinaryOperator {
    /// The `=` binary operator
    static let equal = SQLBinaryOperator("=", negated: "<>")
    
    /// The `<>` binary operator
    static let notEqual = SQLBinaryOperator("<>", negated: "=")
    
    /// The `IS` binary operator
    static let `is` = SQLBinaryOperator("IS", negated: "IS NOT")
    
    /// The `IS NOT` binary operator
    static let isNot = SQLBinaryOperator("IS NOT", negated: "IS")
}

// Outputs "x = y" or "x IS NULL"
private func isEqual(_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLExpression {
    switch (lhs, rhs) {
    case (let lhs, let rhs as DatabaseValue):
        switch rhs.storage {
        case .null:
            return SQLExpressionBinary(.is, lhs, DatabaseValue.null)
        default:
            return SQLExpressionBinary(.equal, lhs, rhs)
        }
    case (let lhs as DatabaseValue, let rhs):
        switch lhs.storage {
        case .null:
            return SQLExpressionBinary(.is, rhs, DatabaseValue.null)
        default:
            return SQLExpressionBinary(.equal, lhs, rhs)
        }
    default:
        return SQLExpressionBinary(.equal, lhs, rhs)
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
    return SQLExpressionBinary(.is, lhs.sqlExpression, rhs?.sqlExpression ?? DatabaseValue.null)
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
        return SQLExpressionBinary(.is, lhs.sqlExpression, rhs.sqlExpression)
    } else {
        return SQLExpressionBinary(.is, rhs.sqlExpression, DatabaseValue.null)
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
    return SQLExpressionBinary(.is, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // name IS NOT 'Arthur'
///     Column("name") !== "Arthur"
public func !== (lhs: SQLSpecificExpressible, rhs: SQLExpressible?) -> SQLExpression {
    return SQLExpressionBinary(.isNot, lhs.sqlExpression, rhs?.sqlExpression ?? DatabaseValue.null)
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
        return SQLExpressionBinary(.isNot, lhs.sqlExpression, rhs.sqlExpression)
    } else {
        return SQLExpressionBinary(.isNot, rhs.sqlExpression, DatabaseValue.null)
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
    return SQLExpressionBinary(.isNot, lhs.sqlExpression, rhs.sqlExpression)
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
    /// The `+` binary operator
    static let plus = SQLBinaryOperator("+")
    
    /// The `-` binary operator
    static let minus = SQLBinaryOperator("-")
    
    /// The `*` binary operator
    static let multiply = SQLBinaryOperator("*")
    
    /// The `/` binary operator
    static let divide = SQLBinaryOperator("/")
}

extension SQLUnaryOperator {
    /// The `-` unary operator
    public static let minus = SQLUnaryOperator("-", needsRightSpace: false)
}

/// An SQL arithmetic multiplication.
///
///     // width * 2
///     Column("width") * 2
public func * (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.multiply, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic multiplication.
///
///     // 2 * width
///     2 * Column("width")
public func * (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.multiply, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic multiplication.
///
///     // width * height
///     Column("width") * Column("height")
public func * (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.multiply, lhs.sqlExpression, rhs.sqlExpression)
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
    return SQLExpressionBinary(.plus, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic addition.
///
///     // 2 + width
///     2 + Column("width")
public func + (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.plus, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic addition.
///
///     // width + height
///     Column("width") + Column("height")
public func + (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.plus, lhs.sqlExpression, rhs.sqlExpression)
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
    return SQLExpressionBinary(.minus, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic substraction.
///
///     // 2 - width
///     2 - Column("width")
public func - (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.minus, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic substraction.
///
///     // width - height
///     Column("width") - Column("height")
public func - (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.minus, lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Logical Operators (AND, OR, NOT)

extension SQLBinaryOperator {
    /// The `AND` binary operator
    static let and = SQLBinaryOperator("AND")
    
    /// The `OR` binary operator
    static let or = SQLBinaryOperator("OR")
}

/// A logical SQL expression with the `AND` SQL operator.
///
///     // favorite AND 0
///     Column("favorite") && false
public func && (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.and, lhs.sqlExpression, rhs.sqlExpression)
}

/// A logical SQL expression with the `AND` SQL operator.
///
///     // 0 AND favorite
///     false && Column("favorite")
public func && (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.and, lhs.sqlExpression, rhs.sqlExpression)
}

/// A logical SQL expression with the `AND` SQL operator.
///
///     // email IS NOT NULL AND favorite
///     Column("email") != nil && Column("favorite")
public func && (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.and, lhs.sqlExpression, rhs.sqlExpression)
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // favorite OR 1
///     Column("favorite") || true
public func || (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    return SQLExpressionBinary(.or, lhs.sqlExpression, rhs.sqlExpression)
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // 0 OR favorite
///     true || Column("favorite")
public func || (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.or, lhs.sqlExpression, rhs.sqlExpression)
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // email IS NULL OR hidden
///     Column("email") == nil || Column("hidden")
public func || (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionBinary(.or, lhs.sqlExpression, rhs.sqlExpression)
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

extension SQLSpecificExpressible {
    
    /// An SQL expression with the `LIKE` SQL operator.
    ///
    ///     // email LIKE '%@example.com"
    ///     Column("email").like("%@example.com")
    public func like(_ pattern: SQLExpressible) -> SQLExpression {
        return SQLExpressionBinary(.like, self, pattern)
    }
}


// MARK: - Match Operator

extension SQLBinaryOperator {
    /// The `MATCH` binary operator
    static let match = SQLBinaryOperator("MATCH")
}
