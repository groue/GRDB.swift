// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

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
    .equal(lhs.sqlExpression, rhs?.sqlExpression ?? .null)
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
        return lhs.sqlExpression.is(.true)
    } else {
        return lhs.sqlExpression.is(.false)
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
    .equal(lhs?.sqlExpression ?? .null, rhs.sqlExpression)
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
        return rhs.sqlExpression.is(.true)
    } else {
        return rhs.sqlExpression.is(.false)
    }
}

/// An SQL expression that compares two expressions with the `=` SQL operator.
///
///     // email = login
///     Column("email") == Column("login")
public func == (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .equal(lhs.sqlExpression, rhs.sqlExpression)
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
    !(lhs == rhs)
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
    !(lhs == rhs)
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
    !(lhs == rhs)
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
    !(lhs == rhs)
}

/// An SQL expression that compares two expressions with the `<>` SQL operator.
///
///     // email <> login
///     Column("email") != Column("login")
public func != (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    !(lhs == rhs)
}

/// An SQL expression that compares two expressions with the `IS` SQL operator.
///
///     // name IS 'Arthur'
///     Column("name") === "Arthur"
public func === (lhs: SQLSpecificExpressible, rhs: SQLExpressible?) -> SQLExpression {
    .compare(.is, lhs.sqlExpression, rhs?.sqlExpression ?? .null)
}

/// An SQL expression that compares two expressions with the `IS` SQL operator.
///
///     // name IS 'Arthur'
///     "Arthur" === Column("name")
public func === (lhs: SQLExpressible?, rhs: SQLSpecificExpressible) -> SQLExpression {
    if let lhs = lhs {
        return .compare(.is, lhs.sqlExpression, rhs.sqlExpression)
    } else {
        return .compare(.is, rhs.sqlExpression, .null)
    }
}

/// An SQL expression that compares two expressions with the `IS` SQL operator.
///
///     // email IS login
///     Column("email") === Column("login")
public func === (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .compare(.is, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // name IS NOT 'Arthur'
///     Column("name") !== "Arthur"
public func !== (lhs: SQLSpecificExpressible, rhs: SQLExpressible?) -> SQLExpression {
    !(lhs === rhs)
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // name IS NOT 'Arthur'
///     "Arthur" !== Column("name")
public func !== (lhs: SQLExpressible?, rhs: SQLSpecificExpressible) -> SQLExpression {
    !(lhs === rhs)
}

/// An SQL expression that compares two expressions with the `IS NOT` SQL operator.
///
///     // email IS NOT login
///     Column("email") !== Column("login")
public func !== (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    !(lhs === rhs)
}

// MARK: - Comparison Operators (<, >, <=, >=)

/// An SQL expression that compares two expressions with the `<` SQL operator.
///
///     // score < 18
///     Column("score") < 18
public func < (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .binary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<` SQL operator.
///
///     // 18 < score
///     18 < Column("score")
public func < (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<` SQL operator.
///
///     // width < height
///     Column("width") < Column("height")
public func < (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<=` SQL operator.
///
///     // score <= 18
///     Column("score") <= 18
public func <= (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .binary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<=` SQL operator.
///
///     // 18 <= score
///     18 <= Column("score")
public func <= (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `<=` SQL operator.
///
///     // width <= height
///     Column("width") <= Column("height")
public func <= (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>` SQL operator.
///
///     // score > 18
///     Column("score") > 18
public func > (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .binary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>` SQL operator.
///
///     // 18 > score
///     18 > Column("score")
public func > (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>` SQL operator.
///
///     // width > height
///     Column("width") > Column("height")
public func > (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>=` SQL operator.
///
///     // score >= 18
///     Column("score") >= 18
public func >= (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .binary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>=` SQL operator.
///
///     // 18 >= score
///     18 >= Column("score")
public func >= (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL expression that compares two expressions with the `>=` SQL operator.
///
///     // width >= height
///     Column("width") >= Column("height")
public func >= (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
}

// MARK: - Inclusion Operators (BETWEEN, IN)

extension Range where Bound: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // email >= 'A' AND email < 'B'
    ///     ("A"..<"B").contains(Column("email"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        (element >= lowerBound) && (element < upperBound)
    }
}

extension ClosedRange where Bound: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // email BETWEEN 'A' AND 'B'
    ///     ("A"..."B").contains(Column("email"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        .between(
            expression: element.sqlExpression,
            lowerBound: lowerBound.sqlExpression,
            upperBound: upperBound.sqlExpression)
    }
}

extension CountableRange where Bound: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // id BETWEEN 1 AND 9
    ///     (1..<10).contains(Column("id"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        (element >= lowerBound) && (element < upperBound)
    }
}

extension CountableClosedRange where Bound: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in a range.
    ///
    ///     // id BETWEEN 1 AND 10
    ///     (1...10).contains(Column("id"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        .between(
            expression: element.sqlExpression,
            lowerBound: lowerBound.sqlExpression,
            upperBound: upperBound.sqlExpression)
    }
}

extension Sequence where Self.Iterator.Element: SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in
    /// a sequence.
    ///
    ///     // id IN (1,2,3)
    ///     [1, 2, 3].contains(Column("id"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        SQLCollection.array(map(\.sqlExpression)).contains(element.sqlExpression)
    }
}

extension Sequence where Self.Iterator.Element == SQLExpressible {
    /// An SQL expression that checks the inclusion of an expression in
    /// a sequence.
    ///
    ///     // id IN (1,2,3)
    ///     [1, 2, 3].contains(Column("id"))
    public func contains(_ element: SQLSpecificExpressible) -> SQLExpression {
        SQLCollection.array(map(\.sqlExpression)).contains(element.sqlExpression)
    }
}


// MARK: - Arithmetic Operators (+, -, *, /)

/// An SQL arithmetic multiplication.
///
///     // width * 2
///     Column("width") * 2
public func * (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .associativeBinary(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic multiplication.
///
///     // 2 * width
///     2 * Column("width")
public func * (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .associativeBinary(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic multiplication.
///
///     // width * height
///     Column("width") * Column("height")
public func * (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .associativeBinary(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic division.
///
///     // width / 2
///     Column("width") / 2
public func / (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .binary(.divide, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic division.
///
///     // 2 / width
///     2 / Column("width")
public func / (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.divide, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic division.
///
///     // width / height
///     Column("width") / Column("height")
public func / (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.divide, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic addition.
///
///     // width + 2
///     Column("width") + 2
public func + (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .associativeBinary(.add, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic addition.
///
///     // 2 + width
///     2 + Column("width")
public func + (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .associativeBinary(.add, [lhs.sqlExpression, rhs.sqlExpression])
}

/// An SQL arithmetic addition.
///
///     // width + height
///     Column("width") + Column("height")
public func + (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .associativeBinary(.add, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A negated SQL arithmetic expression.
///
///     // -width
///     -Column("width")
public prefix func - (value: SQLSpecificExpressible) -> SQLExpression {
    .unary(.minus, value.sqlExpression)
}

/// An SQL arithmetic substraction.
///
///     // width - 2
///     Column("width") - 2
public func - (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .binary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic substraction.
///
///     // 2 - width
///     2 - Column("width")
public func - (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
}

/// An SQL arithmetic substraction.
///
///     // width - height
///     Column("width") - Column("height")
public func - (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .binary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Logical Operators (AND, OR, NOT)

/// A logical SQL expression with the `AND` SQL operator.
///
///     // favorite AND 0
///     Column("favorite") && false
public func && (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .associativeBinary(.and, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `AND` SQL operator.
///
///     // 0 AND favorite
///     false && Column("favorite")
public func && (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .associativeBinary(.and, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `AND` SQL operator.
///
///     // email IS NOT NULL AND favorite
///     Column("email") != nil && Column("favorite")
public func && (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .associativeBinary(.and, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // favorite OR 1
///     Column("favorite") || true
public func || (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .associativeBinary(.or, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // 0 OR favorite
///     true || Column("favorite")
public func || (lhs: SQLExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .associativeBinary(.or, [lhs.sqlExpression, rhs.sqlExpression])
}

/// A logical SQL expression with the `OR` SQL operator.
///
///     // email IS NULL OR hidden
///     Column("email") == nil || Column("hidden")
public func || (lhs: SQLSpecificExpressible, rhs: SQLSpecificExpressible) -> SQLExpression {
    .associativeBinary(.or, [lhs.sqlExpression, rhs.sqlExpression])
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
    value.sqlExpression.is(.falsey)
}

// MARK: - Like Operator

extension SQLSpecificExpressible {
    
    /// An SQL expression with the `LIKE` SQL operator.
    ///
    ///     // email LIKE '%@example.com"
    ///     Column("email").like("%@example.com")
    ///
    ///     // title LIKE '%10\%%' ESCAPE '\'
    ///     Column("title").like("%10\\%%", escape: "\\")
    public func like(_ pattern: SQLExpressible, escape: SQLExpressible? = nil) -> SQLExpression {
        .escapableBinary(.like, sqlExpression, pattern.sqlExpression, escape: escape?.sqlExpression)
    }
}
