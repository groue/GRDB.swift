extension SQLSpecificExpressible {
    // MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)
    
    /// Compares two SQL expressions.
    ///
    /// For example:
    ///
    /// ```swift
    /// // name = 'Arthur'
    /// Column("name") == "Arthur"
    /// ```
    ///
    /// When the right operand is nil, `IS NULL` is used instead of the
    /// `=` operator:
    ///
    /// ```swift
    /// // name IS NULL
    /// Column("name") == nil
    /// ```
    public static func == (lhs: Self, rhs: (any SQLExpressible)?) -> SQLExpression {
        .equal(lhs.sqlExpression, rhs?.sqlExpression ?? .null)
    }
    
    /// The `=` SQL operator.
    public static func == (lhs: Self, rhs: Bool) -> SQLExpression {
        if rhs {
            return lhs.sqlExpression.is(.true)
        } else {
            return lhs.sqlExpression.is(.false)
        }
    }
    
    /// Compares two SQL expressions.
    ///
    /// For example:
    ///
    /// ```swift
    /// // 'Arthur' = name
    /// "Arthur" == Column("name")
    /// ```
    ///
    /// When the left operand is nil, `IS NULL` is used instead of the
    /// `=` operator:
    ///
    /// ```swift
    /// // name IS NULL
    /// nil == Column("name")
    /// ```
    public static func == (lhs: (any SQLExpressible)?, rhs: Self) -> SQLExpression {
        .equal(lhs?.sqlExpression ?? .null, rhs.sqlExpression)
    }
    
    /// The `=` SQL operator.
    public static func == (lhs: Bool, rhs: Self) -> SQLExpression {
        if lhs {
            return rhs.sqlExpression.is(.true)
        } else {
            return rhs.sqlExpression.is(.false)
        }
    }
    
    /// The `=` SQL operator.
    public static func == (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .equal(lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// Compares two SQL expressions.
    ///
    /// For example:
    ///
    /// ```swift
    /// // name <> 'Arthur'
    /// Column("name") != "Arthur"
    /// ```
    ///
    /// When the right operand is nil, `IS NOT NULL` is used instead of the
    /// `<>` operator:
    ///
    /// ```swift
    /// // name IS NOT NULL
    /// Column("name") != nil
    /// ```
    public static func != (lhs: Self, rhs: (any SQLExpressible)?) -> SQLExpression {
        !(lhs == rhs)
    }
    
    /// The `<>` SQL operator.
    public static func != (lhs: Self, rhs: Bool) -> SQLExpression {
        !(lhs == rhs)
    }
    
    /// Compares two SQL expressions.
    ///
    /// For example:
    ///
    /// ```swift
    /// // 'Arthur' <> name
    /// "Arthur" != Column("name")
    /// ```
    ///
    /// When the left operand is nil, `IS NOT NULL` is used instead of the
    /// `<>` operator:
    ///
    /// ```swift
    /// // name IS NOT NULL
    /// nil != Column("name")
    /// ```
    public static func != (lhs: (any SQLExpressible)?, rhs: Self) -> SQLExpression {
        !(lhs == rhs)
    }
    
    /// The `<>` SQL operator.
    public static func != (lhs: Bool, rhs: Self) -> SQLExpression {
        !(lhs == rhs)
    }
    
    /// The `<>` SQL operator.
    public static func != (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        !(lhs == rhs)
    }
    
    /// The `IS` SQL operator.
    public static func === (lhs: Self, rhs: (any SQLExpressible)?) -> SQLExpression {
        .compare(.is, lhs.sqlExpression, rhs?.sqlExpression ?? .null)
    }
    
    /// The `IS` SQL operator.
    public static func === (lhs: (any SQLExpressible)?, rhs: Self) -> SQLExpression {
        if let lhs {
            return .compare(.is, lhs.sqlExpression, rhs.sqlExpression)
        } else {
            return .compare(.is, rhs.sqlExpression, .null)
        }
    }
    
    /// The `IS` SQL operator.
    public static func === (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .compare(.is, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `IS NOT` SQL operator.
    public static func !== (lhs: Self, rhs: (any SQLExpressible)?) -> SQLExpression {
        !(lhs === rhs)
    }
    
    /// The `IS NOT` SQL operator.
    public static func !== (lhs: (any SQLExpressible)?, rhs: Self) -> SQLExpression {
        !(lhs === rhs)
    }
    
    /// The `IS NOT` SQL operator.
    public static func !== (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        !(lhs === rhs)
    }
    
    // MARK: - Comparison Operators (<, >, <=, >=)
    
    /// The `<` SQL operator.
    public static func < (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .binary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `<` SQL operator.
    public static  func < (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .binary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `<` SQL operator.
    public static func < (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .binary(.lessThan, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `<=` SQL operator.
    public static func <= (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .binary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `<=` SQL operator.
    public static func <= (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .binary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `<=` SQL operator.
    public static func <= (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .binary(.lessThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>` SQL operator.
    public static func > (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .binary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>` SQL operator.
    public static func > (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .binary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>` SQL operator.
    public static func > (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .binary(.greaterThan, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>=` SQL operator.
    public static func >= (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .binary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>=` SQL operator.
    public static func >= (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .binary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>=` SQL operator.
    public static func >= (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .binary(.greaterThanOrEqual, lhs.sqlExpression, rhs.sqlExpression)
    }
}

// MARK: - Inclusion Operators (BETWEEN, IN)

extension Range where Bound: SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of an expression in
    /// a range.
    ///
    /// For example:
    ///
    /// ```swift
    /// // email >= 'A' AND email < 'B'
    /// ("A"..<"B").contains(Column("email"))
    /// ```
    public func contains(_ element: some SQLSpecificExpressible) -> SQLExpression {
        (element >= lowerBound) && (element < upperBound)
    }
}

extension ClosedRange where Bound: SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of an expression in
    /// a range.
    ///
    /// For example:
    ///
    /// ```swift
    /// // initial BETWEEN 'A' AND 'B'
    /// ("A"..."B").contains(Column("initial"))
    /// ```
    public func contains(_ element: some SQLSpecificExpressible) -> SQLExpression {
        .between(
            expression: element.sqlExpression,
            lowerBound: lowerBound.sqlExpression,
            upperBound: upperBound.sqlExpression)
    }
}

extension CountableRange where Bound: SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of an expression in
    /// a range.
    ///
    /// For example:
    ///
    /// ```swift
    /// // id >= 1 AND id < 10
    /// (1..<10).contains(Column("id"))
    /// ```
    public func contains(_ element: some SQLSpecificExpressible) -> SQLExpression {
        (element >= lowerBound) && (element < upperBound)
    }
}

extension CountableClosedRange where Bound: SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of an expression in
    /// a range.
    ///
    /// For example:
    ///
    /// ```swift
    /// // id BETWEEN 1 AND 10
    /// (1...10).contains(Column("id"))
    /// ```
    public func contains(_ element: some SQLSpecificExpressible) -> SQLExpression {
        .between(
            expression: element.sqlExpression,
            lowerBound: lowerBound.sqlExpression,
            upperBound: upperBound.sqlExpression)
    }
}

extension Sequence where Element: SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of an expression in
    /// a sequence.
    ///
    /// For example:
    ///
    /// ```swift
    /// // id IN (1,2,3)
    /// [1, 2, 3].contains(Column("id"))
    /// ```
    public func contains(_ element: some SQLSpecificExpressible) -> SQLExpression {
        SQLCollection.array(map(\.sqlExpression)).contains(element.sqlExpression)
    }
}

extension Sequence where Element == any SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of an expression in
    /// a sequence.
    ///
    /// For example:
    ///
    /// ```swift
    /// // id IN (1,2,3)
    /// [1, 2, 3].contains(Column("id"))
    /// ```
    public func contains(_ element: some SQLSpecificExpressible) -> SQLExpression {
        SQLCollection.array(map(\.sqlExpression)).contains(element.sqlExpression)
    }
}


// MARK: - Arithmetic Operators (+, -, *, /)

extension SQLSpecificExpressible {
    /// The `*` SQL operator.
    public static func * (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .associativeBinary(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `*` SQL operator.
    public static func * (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .associativeBinary(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `*` SQL operator.
    public static func * (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .associativeBinary(.multiply, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `/` SQL operator.
    public static func / (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .binary(.divide, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `/` SQL operator.
    public static func / (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .binary(.divide, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `/` SQL operator.
    public static func / (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .binary(.divide, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `+` SQL operator.
    public static func + (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .associativeBinary(.add, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `+` SQL operator.
    public static func + (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .associativeBinary(.add, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `+` SQL operator.
    public static func + (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .associativeBinary(.add, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `-` SQL operator.
    public static prefix func - (value: Self) -> SQLExpression {
        .unary(.minus, value.sqlExpression)
    }
    
    /// The `-` SQL operator.
    public static func - (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .binary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `-` SQL operator.
    public static func - (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .binary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `-` SQL operator.
    public static func - (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .binary(.subtract, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    
    // MARK: - Logical Operators (AND, OR, NOT)
    
    /// The `AND` SQL operator.
    public static func && (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .associativeBinary(.and, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `AND` SQL operator.
    public static func && (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .associativeBinary(.and, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `AND` SQL operator.
    public static func && (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .associativeBinary(.and, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `OR` SQL operator.
    public static func || (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .associativeBinary(.or, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `OR` SQL operator.
    public static func || (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .associativeBinary(.or, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `OR` SQL operator.
    public static func || (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .associativeBinary(.or, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// A negated logical SQL expression.
    ///
    /// For example:
    ///
    /// ```swift
    /// // NOT isBlue
    /// !Column("isBlue")
    /// ```
    ///
    /// Some expressions are negated with specific SQL operators:
    ///
    /// ```swift
    /// // id NOT BETWEEN 1 AND 10
    /// !((1...10).contains(Column("id")))
    /// ```
    public static prefix func ! (value: Self) -> SQLExpression {
        value.sqlExpression.is(.falsey)
    }
}

// MARK: - Bitwise Operators (&, |, ~, <<, >>)

extension SQLSpecificExpressible {
    /// The `&` SQL operator.
    public static func & (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .associativeBinary(.bitwiseAnd, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `&` SQL operator.
    public static func & (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .associativeBinary(.bitwiseAnd, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `&` SQL operator.
    public static func & (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .associativeBinary(.bitwiseAnd, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `|` SQL operator.
    public static func | (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .associativeBinary(.bitwiseOr, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `|` SQL operator.
    public static func | (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .associativeBinary(.bitwiseOr, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `|` SQL operator.
    public static func | (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .associativeBinary(.bitwiseOr, [lhs.sqlExpression, rhs.sqlExpression])
    }
    
    /// The `<<` SQL operator.
    public static func << (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .binary(.leftShift, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `<<` SQL operator.
    public static func << (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .binary(.leftShift, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `<<` SQL operator.
    public static func << (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .binary(.leftShift, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>>` SQL operator.
    public static func >> (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .binary(.rightShift, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>>` SQL operator.
    public static func >> (lhs: some SQLExpressible, rhs: Self) -> SQLExpression {
        .binary(.rightShift, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `>>` SQL operator.
    public static func >> (lhs: Self, rhs: some SQLSpecificExpressible) -> SQLExpression {
        .binary(.rightShift, lhs.sqlExpression, rhs.sqlExpression)
    }
    
    /// The `~` SQL operator.
    public static prefix func ~ (value: Self) -> SQLExpression {
        .unary(.bitwiseNot, value.sqlExpression)
    }
}

// MARK: - Like Operator

extension SQLSpecificExpressible {
    /// The `LIKE` SQL operator.
    ///
    /// For example:
    ///
    /// ```swift
    /// // email LIKE '%@example.com"
    /// Column("email").like("%@example.com")
    ///
    /// // title LIKE '%10\%%' ESCAPE '\'
    /// Column("title").like("%10\\%%", escape: "\\")
    /// ```
    public func like(_ pattern: some SQLExpressible, escape: (any SQLExpressible)? = nil) -> SQLExpression {
        .escapableBinary(.like, sqlExpression, pattern.sqlExpression, escape: escape?.sqlExpression)
    }
}
