// MARK: - DatabaseValueConvertible

/// Lossless conversions from database values and rows
extension DatabaseValueConvertible {
    @usableFromInline
    static func decode(
        from sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self
    {
        let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else {
            throw RowDecodingError.valueMismatch(Self.self, context: context(), databaseValue: dbValue)
        }
    }

    static func decode(
        from dbValue: DatabaseValue,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self
    {
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else {
            throw RowDecodingError.valueMismatch(Self.self, context: context(), databaseValue: dbValue)
        }
    }

    @usableFromInline
    static func decode(from row: Row, atUncheckedIndex index: Int) throws -> Self {
        try decode(
            from: row.impl.databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: row, key: .columnIndex(index)))
    }

    @usableFromInline
    static func decodeIfPresent(
        from sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self?
    {
        let dbValue = DatabaseValue(sqliteStatement: sqliteStatement, index: index)
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            throw RowDecodingError.valueMismatch(Self.self, context: context(), databaseValue: dbValue)
        }
    }

    static func decodeIfPresent(
        from dbValue: DatabaseValue,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self?
    {
        // Use fromDatabaseValue before checking for null: this allows DatabaseValue to convert NULL to .null.
        if let value = fromDatabaseValue(dbValue) {
            return value
        } else if dbValue.isNull {
            return nil
        } else {
            throw RowDecodingError.valueMismatch(Self.self, context: context(), databaseValue: dbValue)
        }
    }

    @usableFromInline
    static func decodeIfPresent(from row: Row, atUncheckedIndex index: Int) throws -> Self? {
        try decodeIfPresent(
            from: row.impl.databaseValue(atUncheckedIndex: index),
            context: RowDecodingContext(row: row, key: .columnIndex(index)))
    }
}

// MARK: - DatabaseValueConvertible & StatementColumnConvertible

/// Lossless conversions from database values and rows
extension DatabaseValueConvertible where Self: StatementColumnConvertible {
    @inlinable
    static func fastDecode(
        from sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self
    {
        guard sqlite3_column_type(sqliteStatement, index) != SQLITE_NULL,
              let value = self.init(sqliteStatement: sqliteStatement, index: index)
        else {
            throw RowDecodingError.valueMismatch(
                Self.self,
                context: context(),
                databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
        }
        return value
    }

    @inlinable
    static func fastDecode(
        from row: Row,
        atUncheckedIndex index: Int)
    throws -> Self
    {
        if let sqliteStatement = row.sqliteStatement {
            return try fastDecode(
                from: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        return try row.fastDecode(Self.self, atUncheckedIndex: index)
    }

    @inlinable
    static func fastDecodeIfPresent(
        from sqliteStatement: SQLiteStatement,
        atUncheckedIndex index: Int32,
        context: @autoclosure () -> RowDecodingContext)
    throws -> Self?
    {
        if sqlite3_column_type(sqliteStatement, index) == SQLITE_NULL {
            return nil
        }
        guard let value = self.init(sqliteStatement: sqliteStatement, index: index) else {
            throw RowDecodingError.valueMismatch(
                Self.self,
                context: context(),
                databaseValue: DatabaseValue(sqliteStatement: sqliteStatement, index: index))
        }
        return value
    }

    @inlinable
    static func fastDecodeIfPresent(
        from row: Row,
        atUncheckedIndex index: Int)
    throws -> Self?
    {
        if let sqliteStatement = row.sqliteStatement {
            return try fastDecodeIfPresent(
                from: sqliteStatement,
                atUncheckedIndex: Int32(index),
                context: RowDecodingContext(row: row, key: .columnIndex(index)))
        }
        return try row.fastDecodeIfPresent(Self.self, atUncheckedIndex: index)
    }
}

// Support for @inlinable decoding
extension Row {
    @usableFromInline
    func fastDecode<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value
    {
        try impl.fastDecode(type, atUncheckedIndex: index)
    }

    @usableFromInline
    func fastDecodeIfPresent<Value: DatabaseValueConvertible & StatementColumnConvertible>(
        _ type: Value.Type,
        atUncheckedIndex index: Int)
    throws -> Value?
    {
        try impl.fastDecodeIfPresent(type, atUncheckedIndex: index)
    }
}
