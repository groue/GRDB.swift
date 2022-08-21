extension Optional: StatementBinding where Wrapped: StatementBinding {
    public func bind(to sqliteStatement: SQLiteStatement, at index: CInt) -> CInt {
        switch self {
        case .none:
            return sqlite3_bind_null(sqliteStatement, index)
        case let .some(value):
            return value.bind(to: sqliteStatement, at: index)
        }
    }
}

extension Optional: SQLExpressible where Wrapped: SQLExpressible {
    public var sqlExpression: SQLExpression {
        switch self {
        case .none:
            return .null
        case let .some(value):
            return value.sqlExpression
        }
    }
}

extension Optional: SQLOrderingTerm where Wrapped: SQLOrderingTerm {
    public var sqlOrdering: SQLOrdering {
        switch self {
        case .none:
            return .expression(.null)
        case let .some(value):
            return value.sqlOrdering
        }
    }
}

extension Optional: SQLSelectable where Wrapped: SQLSelectable {
    public var sqlSelection: SQLSelection {
        switch self {
        case .none:
            return .expression(.null)
        case let .some(value):
            return value.sqlSelection
        }
    }
}

extension Optional: SQLSpecificExpressible where Wrapped: SQLSpecificExpressible { }

extension Optional: DatabaseValueConvertible where Wrapped: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        switch self {
        case .none:
            return .null
        case let .some(value):
            return value.databaseValue
        }
    }
    
    public static func fromMissingColumn() -> Self? {
        .some(.none) // success
    }
    
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        if let value = Wrapped.fromDatabaseValue(dbValue) {
            // Valid value
            return value
        } else if dbValue.isNull {
            // NULL
            return .some(.none)
        } else {
            // Invalid value
            return .none
        }
    }
}

extension Optional: StatementColumnConvertible where Wrapped: StatementColumnConvertible {
    @inline(__always)
    @inlinable
    public static func fromStatement(_ sqliteStatement: SQLiteStatement, atUncheckedIndex index: CInt) -> Self? {
        if let value = Wrapped.fromStatement(sqliteStatement, atUncheckedIndex: index) {
            // Valid value
            return value
        } else if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            // NULL
            return .some(.none)
        } else {
            // Invalid value
            return .none
        }
    }
    
    public init?(sqliteStatement: SQLiteStatement, index: CInt) {
        guard let value = Wrapped(sqliteStatement: sqliteStatement, index: index) else {
            return nil
        }
        self = .some(value)
    }
}
