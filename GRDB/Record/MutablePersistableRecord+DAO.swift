/// DAO takes care of MutablePersistableRecord CRUD
final class DAO<Record: MutablePersistableRecord> {
    /// The database
    let db: Database
    
    /// DAO keeps a copy the record's persistenceContainer, so that this
    /// dictionary is built once whatever the database operation. It is
    /// guaranteed to have at least one (key, value) pair.
    let persistenceContainer: PersistenceContainer
    
    /// The table name
    let databaseTableName: String
    
    /// The table primary key info
    let primaryKey: PrimaryKeyInfo
    
    init(_ db: Database, _ record: Record) throws {
        self.db = db
        databaseTableName = type(of: record).databaseTableName
        primaryKey = try db.primaryKey(databaseTableName)
        persistenceContainer = try PersistenceContainer(db, record)
        GRDBPrecondition(!persistenceContainer.isEmpty, "\(type(of: record)): invalid empty persistence container")
    }
    
    func insertStatement(
        _ db: Database,
        onConflict: Database.ConflictResolution,
        returning selection: [any SQLSelectable])
    throws -> Statement
    {
        let query = InsertQuery(
            onConflict: onConflict,
            tableName: databaseTableName,
            insertedColumns: persistenceContainer.columns)
        
        return try makeStatement(
            sql: query.sql,
            checkedArguments: StatementArguments(persistenceContainer.values),
            returning: selection)
    }
    
    func upsertStatement(
        _ db: Database,
        onConflict conflictTargetColumns: [String],
        doUpdate assignments: ((_ excluded: TableAlias) -> [ColumnAssignment])?,
        updateCondition: ((_ existing: TableAlias, _ excluded: TableAlias) -> any SQLExpressible)? = nil,
        returning selection: [any SQLSelectable])
    throws -> Statement
    {
        // INSERT
        let insertedColumns = persistenceContainer.columns
        let columnsSQL = insertedColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")
        let valuesSQL = databaseQuestionMarks(count: insertedColumns.count)
        var sql = """
            INSERT INTO \(databaseTableName.quotedDatabaseIdentifier) (\(columnsSQL)) \
            VALUES (\(valuesSQL))
            """
        var arguments = StatementArguments(persistenceContainer.values)
        
        // ON CONFLICT
        if conflictTargetColumns.isEmpty {
            sql += " ON CONFLICT"
        } else {
            let targetSQL = conflictTargetColumns
                .map { $0.quotedDatabaseIdentifier }
                .joined(separator: ", ")
            sql += " ON CONFLICT(\(targetSQL))"
        }
        
        // DO UPDATE SET
        // We update explicit assignments from the `assignments` parameter.
        // Other columns are overwritten by inserted values. This makes sure
        // that no information stored in the record is lost, unless explicitly
        // requested by the user.
        sql += " DO UPDATE SET "
        let excluded = TableAlias(name: "excluded")
        var assignments = assignments?(excluded) ?? []
        let lowercaseExcludedColumns = Set(primaryKey.columns.map { $0.lowercased() })
            .union(conflictTargetColumns.map { $0.lowercased() })
        for column in persistenceContainer.columns {
            let lowercasedColumn = column.lowercased()
            if lowercaseExcludedColumns.contains(lowercasedColumn) {
                // excluded (primary key or conflict target)
                continue
            }
            if assignments.contains(where: { $0.columnName.lowercased() == lowercasedColumn }) {
                // already updated from the `assignments` argument
                continue
            }
            // overwrite
            assignments.append(Column(column).set(to: excluded[column]))
        }
        let context = SQLGenerationContext(db)
        let updateSQL = try assignments
            .compactMap { try $0.sql(context) }
            .joined(separator: ", ")
        if updateSQL.isEmpty {
            if !selection.isEmpty {
                // User has asked that no column was overwritten or updated.
                // In case of conflict, the upsert would do nothing, and return
                // nothing: <https://sqlite.org/forum/forumpost/1ead75e2c45de9a5>.
                //
                // But we have a RETURNING clause, so we WANT values to be
                // returned, and we MUST prevent the upsert statement from
                // return nothing. The RETURNING clause is how, for example, we
                // fetch the rowid of the upserted record, and feed record
                // callbacks such as `didInsert`. Not returning any value would
                // be a GRDB bug.
                //
                // So let's make SURE something is returned, and to do so, let's
                // update one column. The first column of the primary key should
                // be ok.
                let column = primaryKey.columns[0].quotedDatabaseIdentifier
                sql += "\(column) = \(column)"
            }
        } else {
            sql += updateSQL
            arguments += context.arguments
        }
        
        // WHERE
        let existing = TableAlias(name: databaseTableName)
        if let condition = updateCondition?(existing, excluded) {
            let context = SQLGenerationContext(db)
            sql += try " WHERE " + condition.sqlExpression.sql(context)
            arguments += context.arguments
        }
        
        return try makeStatement(
            sql: sql,
            checkedArguments: arguments,
            returning: selection)
    }
    
    /// Returns nil if and only if primary key is nil
    func updateStatement(
        columns: Set<String>,
        onConflict: Database.ConflictResolution,
        returning selection: [any SQLSelectable])
    throws -> Statement?
    {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        if primaryKeyValues.allSatisfy({ $0.isNull }) {
            return nil
        }
        
        // Don't update columns not present in columns
        // Don't update columns not present in the persistenceContainer
        // Don't update primary key columns
        let lowercaseUpdatedColumns = Set(columns.map { $0.lowercased() })
            .intersection(persistenceContainer.columns.map { $0.lowercased() })
            .subtracting(primaryKeyColumns.map { $0.lowercased() })
        
        var updatedColumns: [String] = try db
            .columns(in: databaseTableName)
            .map(\.name)
            .filter { lowercaseUpdatedColumns.contains($0.lowercased()) }
        
        if updatedColumns.isEmpty {
            // IMPLEMENTATION NOTE
            //
            // It is important to update something, so that
            // TransactionObserver can observe a change even though this
            // change is useless.
            //
            // The goal is to be able to write tests with minimal tables,
            // including tables made of a single primary key column.
            updatedColumns = primaryKeyColumns
        }
        
        let updatedValues = updatedColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        
        let query = UpdateQuery(
            onConflict: onConflict,
            tableName: databaseTableName,
            updatedColumns: updatedColumns,
            conditionColumns: primaryKeyColumns)
        
        return try makeStatement(
            sql: query.sql,
            checkedArguments: StatementArguments(updatedValues + primaryKeyValues),
            returning: selection)
    }
    
    /// Returns nil if and only if primary key is nil
    func deleteStatement() throws -> Statement? {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        if primaryKeyValues.allSatisfy({ $0.isNull }) {
            return nil
        }
        
        let query = DeleteQuery(
            tableName: databaseTableName,
            conditionColumns: primaryKeyColumns)
        let statement = try db.internalCachedStatement(sql: query.sql)
        statement.setUncheckedArguments(StatementArguments(primaryKeyValues))
        return statement
    }
    
    /// Returns nil if and only if primary key is nil
    func existsStatement() throws -> Statement? {
        // Fail early if primary key does not resolve to a database row.
        let primaryKeyColumns = primaryKey.columns
        let primaryKeyValues = primaryKeyColumns.map {
            persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null
        }
        if primaryKeyValues.allSatisfy({ $0.isNull }) {
            return nil
        }
        
        let query = ExistsQuery(
            tableName: databaseTableName,
            conditionColumns: primaryKeyColumns)
        let statement = try db.internalCachedStatement(sql: query.sql)
        statement.setUncheckedArguments(StatementArguments(primaryKeyValues))
        return statement
    }
    
    /// Throws a RecordError.recordNotFound error
    func recordNotFound() throws -> Never {
        let key = Dictionary(uniqueKeysWithValues: primaryKey.columns.map {
            ($0, persistenceContainer[caseInsensitive: $0]?.databaseValue ?? .null)
        })
        throw RecordError.recordNotFound(
            databaseTableName: databaseTableName,
            key: key)
    }
    
    // Support for the RETURNING clause
    private func makeStatement(
        sql: String,
        checkedArguments arguments: StatementArguments,
        returning selection: [any SQLSelectable])
    throws -> Statement
    {
        if selection.isEmpty {
            let statement = try db.internalCachedStatement(sql: sql)
            // We have built valid arguments: don't check
            statement.setUncheckedArguments(arguments)
            return statement
        } else {
            let context = SQLGenerationContext(db)
            var sql = sql
            var arguments = arguments
            sql += " RETURNING "
            sql += try selection
                .map { try $0.sqlSelection.sql(context) }
                .joined(separator: ", ")
            arguments += context.arguments
            let statement = try db.internalCachedStatement(sql: sql)
            statement.arguments = arguments
            return statement
        }
    }
}

// MARK: - InsertQuery

private struct InsertQuery: Hashable {
    let onConflict: Database.ConflictResolution
    let tableName: String
    let insertedColumns: [String]
}

extension InsertQuery {
    @ReadWriteBox private static var sqlCache: [InsertQuery: String] = [:]
    var sql: String {
        if let sql = Self.sqlCache[self] {
            return sql
        }
        let columnsSQL = insertedColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")
        let valuesSQL = databaseQuestionMarks(count: insertedColumns.count)
        let sql: String
        switch onConflict {
        case .abort:
            sql = """
            INSERT INTO \(tableName.quotedDatabaseIdentifier) (\(columnsSQL)) \
            VALUES (\(valuesSQL))
            """
        default:
            sql = """
            INSERT OR \(onConflict.rawValue) \
            INTO \(tableName.quotedDatabaseIdentifier) (\(columnsSQL)) \
            VALUES (\(valuesSQL))
            """
        }
        Self.sqlCache[self] = sql
        return sql
    }
}

// MARK: - UpdateQuery

private struct UpdateQuery: Hashable {
    let onConflict: Database.ConflictResolution
    let tableName: String
    let updatedColumns: [String]
    let conditionColumns: [String]
}

extension UpdateQuery {
    @ReadWriteBox private static var sqlCache: [UpdateQuery: String] = [:]
    var sql: String {
        if let sql = Self.sqlCache[self] {
            return sql
        }
        let updateSQL = updatedColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: ", ")
        let whereSQL = conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: " AND ")
        let sql: String
        switch onConflict {
        case .abort:
            sql = """
                UPDATE \(tableName.quotedDatabaseIdentifier) \
                SET \(updateSQL) \
                WHERE \(whereSQL)
                """
        default:
            sql = """
                UPDATE OR \(onConflict.rawValue) \(tableName.quotedDatabaseIdentifier) \
                SET \(updateSQL) \
                WHERE \(whereSQL)
                """
        }
        Self.sqlCache[self] = sql
        return sql
    }
}

// MARK: - DeleteQuery

private struct DeleteQuery {
    let tableName: String
    let conditionColumns: [String]
}

extension DeleteQuery {
    var sql: String {
        let whereSQL = conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: " AND ")
        return "DELETE FROM \(tableName.quotedDatabaseIdentifier) WHERE \(whereSQL)"
    }
}

// MARK: - ExistsQuery

private struct ExistsQuery {
    let tableName: String
    let conditionColumns: [String]
}

extension ExistsQuery {
    var sql: String {
        let whereSQL = conditionColumns.map { "\($0.quotedDatabaseIdentifier)=?" }.joined(separator: " AND ")
        return "SELECT EXISTS (SELECT 1 FROM \(tableName.quotedDatabaseIdentifier) WHERE \(whereSQL))"
    }
}
