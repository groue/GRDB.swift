extension SQLSelectable where Self: RawRepresentable, Self.RawValue: SQLSelectable {
    public var sqlSelection: SQLSelection {
        rawValue.sqlSelection
    }
}

extension SQLOrderingTerm where Self: RawRepresentable, Self.RawValue: SQLOrderingTerm {
    public var sqlOrdering: SQLOrdering {
        rawValue.sqlOrdering
    }
}

extension SQLExpressible where Self: RawRepresentable, Self.RawValue: SQLExpressible {
    /// Returns the raw value as an SQL expression.
    public var sqlExpression: SQLExpression {
        rawValue.sqlExpression
    }
}

extension StatementBinding where Self: RawRepresentable, Self.RawValue: StatementBinding {
    public func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt {
        rawValue.bind(to: sqliteStatement, at: index)
    }
}

/// `DatabaseValueConvertible` is free for `RawRepresentable` types whose raw
/// value is itself `DatabaseValueConvertible`.
///
///     // If the RawValue adopts DatabaseValueConvertible...
///     enum Color : Int {
///         case red
///         case white
///         case rose
///     }
///
///     // ... then the RawRepresentable type can freely
///     // adopt DatabaseValueConvertible:
///     extension Color: DatabaseValueConvertible { }
extension DatabaseValueConvertible where Self: RawRepresentable, Self.RawValue: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawValue.databaseValue
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        RawValue.fromDatabaseValue(dbValue).flatMap { self.init(rawValue: $0) }
    }
}
