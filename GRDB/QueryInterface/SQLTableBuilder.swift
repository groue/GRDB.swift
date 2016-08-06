extension Database {
    // TODO: doc
    @available(iOS 8.2, OSX 10.10, *)
    public func create(table name: String, temporary: Bool = false, ifNotExists: Bool = false, withoutRowID: Bool, body: (SQLTableBuilder) -> Void) throws {
        // WITHOUT ROWID was added in SQLite 3.8.2 http://www.sqlite.org/changes.html#version_3_8_2
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        let builder = SQLTableBuilder(name: name, temporary: temporary, ifNotExists: ifNotExists, withoutRowID: withoutRowID)
        body(builder)
        let sql = try builder.sql(self)
        try execute(sql)
    }

    // TODO: doc
    public func create(table name: String, temporary: Bool = false, ifNotExists: Bool = false, body: (SQLTableBuilder) -> Void) throws {
        let builder = SQLTableBuilder(name: name, temporary: temporary, ifNotExists: ifNotExists, withoutRowID: false)
        body(builder)
        let sql = try builder.sql(self)
        try execute(sql)
    }
    
    // TODO: doc
    public func rename(table name: String, to newName: String) throws {
        try execute("ALTER TABLE \(name.quotedDatabaseIdentifier) RENAME TO \(newName.quotedDatabaseIdentifier)")
    }
    
    // TODO: doc
    public func alter(table name: String, body: (SQLTableAlterationBuilder) -> Void) throws {
        let builder = SQLTableAlterationBuilder(name: name)
        body(builder)
        let sql = try builder.sql(self)
        try execute(sql)
    }
    
    // TODO: doc
    public func drop(table name: String) throws {
        try execute("DROP TABLE \(name.quotedDatabaseIdentifier)")
    }
    
    // TODO: doc
    public func create(index name: String, on table: String, columns: [String], unique: Bool = false, ifNotExists: Bool = false, condition: _SQLExpressible? = nil) throws {
        let builder = IndexBuilder(name: name, table: table, columns: columns, unique: unique, ifNotExists: ifNotExists, condition: condition?.sqlExpression)
        let sql = builder.sql()
        try execute(sql)
    }
    
    // TODO: doc
    public func drop(index name: String) throws {
        try execute("DROP INDEX \(name.quotedDatabaseIdentifier)")
    }
}

// TODO: doc
public final class SQLTableBuilder {
    let name: String
    let temporary: Bool
    let ifNotExists: Bool
    let withoutRowID: Bool
    var columns: [SQLColumnBuilder] = []
    var primaryKeyConstraint: (columns: [String], conflictResolution: SQLConflictResolution?)?
    var uniqueKeyConstraints: [(columns: [String], conflictResolution: SQLConflictResolution?)] = []
    var foreignKeyConstraints: [(columns: [String], table: String, destinationColumns: [String]?, deleteAction: SQLForeignKeyAction?, updateAction: SQLForeignKeyAction?, deferred: Bool)] = []
    var checkConstraints: [_SQLExpression] = []
    
    init(name: String, temporary: Bool, ifNotExists: Bool, withoutRowID: Bool) {
        self.name = name
        self.temporary = temporary
        self.ifNotExists = ifNotExists
        self.withoutRowID = withoutRowID
    }
    
    // TODO: doc
    public func column(name: String, _ type: SQLColumnType) -> SQLColumnBuilder {
        let column = SQLColumnBuilder(name: name, type: type)
        columns.append(column)
        return column
    }
    
    // TODO: doc
    public func primaryKey(columns: [String], onConflict conflictResolution: SQLConflictResolution? = nil) {
        guard primaryKeyConstraint == nil else {
            fatalError("can't define several primary keys")
        }
        primaryKeyConstraint = (columns: columns, conflictResolution: conflictResolution)
    }
    
    // TODO: doc
    public func uniqueKey(columns: [String], onConflict conflictResolution: SQLConflictResolution? = nil) {
        uniqueKeyConstraints.append((columns: columns, conflictResolution: conflictResolution))
    }
    
    // TODO: doc
    public func foreignKey(columns: [String], references table: String, columns destinationColumns: [String]? = nil, onDelete deleteAction: SQLForeignKeyAction? = nil, onUpdate updateAction: SQLForeignKeyAction? = nil, deferred: Bool = false) {
        foreignKeyConstraints.append((columns: columns, table: table, destinationColumns: destinationColumns, deleteAction: deleteAction, updateAction: updateAction, deferred: deferred))
    }
    
    // TODO: doc
    public func check(condition: _SQLExpressible) {
        checkConstraints.append(condition.sqlExpression)
    }
    
    // TODO: doc
    public func check(sql sql: String) {
        checkConstraints.append(_SQLExpression.Literal(sql, nil))
    }
}

// TODO: doc
public final class SQLTableAlterationBuilder {
    let name: String
    var addedColumns: [SQLColumnBuilder] = []
    
    init(name: String) {
        self.name = name
    }
    
    // TODO: doc
    public func add(column name: String, _ type: SQLColumnType) -> SQLColumnBuilder {
        let column = SQLColumnBuilder(name: name, type: type)
        addedColumns.append(column)
        return column
    }
}

// TODO: doc
public final class SQLColumnBuilder {
    let name: String
    let type: SQLColumnType
    var primaryKey: (ordering: SQLOrdering?, conflictResolution: SQLConflictResolution?, autoincrement: Bool)?
    var notNullConflictResolution: SQLConflictResolution?
    var uniqueConflictResolution: SQLConflictResolution?
    var checkExpression: _SQLExpression?
    var defaultExpression: _SQLExpression?
    var collationName: String?
    var reference: (table: String, column: String?, deleteAction: SQLForeignKeyAction?, updateAction: SQLForeignKeyAction?, deferred: Bool)?
    
    init(name: String, type: SQLColumnType) {
        self.name = name
        self.type = type
    }
    
    // TODO: doc
    public func primaryKey(ordering ordering: SQLOrdering? = nil, onConflict conflictResolution: SQLConflictResolution? = nil, autoincrement: Bool = false) -> SQLColumnBuilder {
        primaryKey = (ordering: ordering, conflictResolution: conflictResolution, autoincrement: autoincrement)
        return self
    }
    
    // TODO: doc
    public func notNull(onConflict conflictResolution: SQLConflictResolution? = nil) -> SQLColumnBuilder {
        notNullConflictResolution = conflictResolution ?? .Abort
        return self
    }
    
    // TODO: doc
    public func unique(onConflict conflictResolution: SQLConflictResolution? = nil) -> SQLColumnBuilder {
        uniqueConflictResolution = conflictResolution ?? .Abort
        return self
    }
    
    // TODO: doc
    public func check(@noescape condition: (SQLColumn) -> _SQLExpressible) -> SQLColumnBuilder {
        checkExpression = condition(SQLColumn(name)).sqlExpression
        return self
    }
    
    // TODO: doc
    public func check(sql sql: String) -> SQLColumnBuilder {
        checkExpression = _SQLExpression.Literal(sql, nil)
        return self
    }
    
    // TODO: doc
    public func defaults(value: DatabaseValueConvertible) -> SQLColumnBuilder {
        defaultExpression = value.sqlExpression
        return self
    }
    
    // TODO: doc
    public func defaults(sql sql: String) -> SQLColumnBuilder {
        defaultExpression = _SQLExpression.Literal(sql, nil)
        return self
    }
    
    // TODO: doc
    public func collate(collation: SQLCollation) -> SQLColumnBuilder {
        collationName = collation.rawValue
        return self
    }
    
    // TODO: doc
    public func collate(collation: DatabaseCollation) -> SQLColumnBuilder {
        collationName = collation.name
        return self
    }
    
    // TODO: doc
    public func references(table: String, column: String? = nil, onDelete deleteAction: SQLForeignKeyAction? = nil, onUpdate updateAction: SQLForeignKeyAction? = nil, deferred: Bool = false) -> SQLColumnBuilder {
        reference = (table: table, column: column, deleteAction: deleteAction, updateAction: updateAction, deferred: deferred)
        return self
    }
}

// TODO: doc
public enum SQLOrdering : String {
    case Asc = "ASC"
    case Desc = "DESC"
}

// TODO: doc
public enum SQLCollation : String {
    case Binary = "BINARY"
    case Nocase = "NOCASE"
    case Rtrim = "RTRIM"
}

// TODO: doc
public enum SQLConflictResolution : String {
    case Rollback = "ROLLBACK"
    case Abort = "ABORT"
    case Fail = "FAIL"
    case Ignore = "IGNORE"
    case Replace = "REPLACE"
}

// TODO: doc
public enum SQLColumnType : String {
    case Text = "TEXT"
    case Integer = "INTEGER"
    case Double = "DOUBLE"
    case Numeric = "NUMERIC"
    case Boolean = "BOOLEAN"
    case Blob = "BLOB"
    case Date = "DATE"
    case Datetime = "DATETIME"
}

// TODO: doc
public enum SQLForeignKeyAction : String {
    case Cascade = "CASCADE"
    case Restrict = "RESTRICT"
    case SetNull = "SET NULL"
    case SetDefault = "SET DEFAULT"
}


// MARK: - SQL Generation

extension SQLTableBuilder {
    func sql(db: Database) throws -> String {
        var chunks: [String] = []
        chunks.append("CREATE")
        if temporary {
            chunks.append("TEMPORARY")
        }
        chunks.append("TABLE")
        if ifNotExists {
            chunks.append("IF NOT EXISTS")
        }
        chunks.append(name.quotedDatabaseIdentifier)
        
        do {
            var items: [String] = []
            try items.appendContentsOf(columns.map { try $0.sql(db) })
            
            if let (columns, conflictResolution) = primaryKeyConstraint {
                var chunks: [String] = []
                chunks.append("PRIMARY KEY")
                chunks.append("(\((columns.map { $0.quotedDatabaseIdentifier } as [String]).joinWithSeparator(", ")))")
                if let conflictResolution = conflictResolution {
                    chunks.append("ON CONFLICT")
                    chunks.append(conflictResolution.rawValue)
                }
                items.append(chunks.joinWithSeparator(" "))
            }
            
            for (columns, conflictResolution) in uniqueKeyConstraints {
                var chunks: [String] = []
                chunks.append("UNIQUE")
                chunks.append("(\((columns.map { $0.quotedDatabaseIdentifier } as [String]).joinWithSeparator(", ")))")
                if let conflictResolution = conflictResolution {
                    chunks.append("ON CONFLICT")
                    chunks.append(conflictResolution.rawValue)
                }
                items.append(chunks.joinWithSeparator(" "))
            }
            
            for (columns, table, destinationColumns, deleteAction, updateAction, deferred) in foreignKeyConstraints {
                var chunks: [String] = []
                chunks.append("FOREIGN KEY")
                chunks.append("(\((columns.map { $0.quotedDatabaseIdentifier } as [String]).joinWithSeparator(", ")))")
                chunks.append("REFERENCES")
                if let destinationColumns = destinationColumns {
                    chunks.append("\(table.quotedDatabaseIdentifier)(\((destinationColumns.map { $0.quotedDatabaseIdentifier } as [String]).joinWithSeparator(", ")))")
                } else if let primaryKey = try db.primaryKey(table) {
                    chunks.append("\(table.quotedDatabaseIdentifier)(\((primaryKey.columns.map { $0.quotedDatabaseIdentifier } as [String]).joinWithSeparator(", ")))")
                } else {
                    fatalError("explicit referenced column(s) required, since table \(table) has no primary key")
                }
                if let deleteAction = deleteAction {
                    chunks.append("ON DELETE")
                    chunks.append(deleteAction.rawValue)
                }
                if let updateAction = updateAction {
                    chunks.append("ON UPDATE")
                    chunks.append(updateAction.rawValue)
                }
                if deferred {
                    chunks.append("DEFERRABLE INITIALLY DEFERRED")
                }
                items.append(chunks.joinWithSeparator(" "))
            }
            
            for checkExpression in checkConstraints {
                var chunks: [String] = []
                chunks.append("CHECK")
                var arguments: StatementArguments? = nil // nil so that checkExpression.sql(&arguments) embeds literals
                chunks.append("(" + checkExpression.sql(&arguments) + ")")
                items.append(chunks.joinWithSeparator(" "))
            }
            
            chunks.append("(\(items.joinWithSeparator(", ")))")
        }
        
        if withoutRowID {
            chunks.append("WITHOUT ROWID")
        }
        return chunks.joinWithSeparator(" ")
    }
}

extension SQLTableAlterationBuilder {
    func sql(db: Database) throws -> String {
        var statements: [String] = []
        
        for column in addedColumns {
            var chunks: [String] = []
            chunks.append("ALTER TABLE")
            chunks.append(name.quotedDatabaseIdentifier)
            chunks.append("ADD COLUMN")
            try chunks.append(column.sql(db))
            let statement = chunks.joinWithSeparator(" ")
            statements.append(statement)
        }
        
        return statements.joinWithSeparator("; ")
    }
}

extension SQLColumnBuilder {
    func sql(db: Database) throws -> String {
        var chunks: [String] = []
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append(type.rawValue)
        
        if let (ordering, conflictResolution, autoincrement) = primaryKey {
            chunks.append("PRIMARY KEY")
            if let ordering = ordering {
                chunks.append(ordering.rawValue)
            }
            if let conflictResolution = conflictResolution {
                chunks.append("ON CONFLICT")
                chunks.append(conflictResolution.rawValue)
            }
            if autoincrement {
                chunks.append("AUTOINCREMENT")
            }
        }
        
        switch notNullConflictResolution {
        case .None:
            break
        case .Abort?:
            chunks.append("NOT NULL")
        case let conflictResolution?:
            chunks.append("NOT NULL ON CONFLICT")
            chunks.append(conflictResolution.rawValue)
        }
        
        switch uniqueConflictResolution {
        case .None:
            break
        case .Abort?:
            chunks.append("UNIQUE")
        case let conflictResolution?:
            chunks.append("UNIQUE ON CONFLICT")
            chunks.append(conflictResolution.rawValue)
        }
        
        if let checkExpression = checkExpression {
            chunks.append("CHECK")
            var arguments: StatementArguments? = nil // nil so that checkExpression.sql(&arguments) embeds literals
            chunks.append("(" + checkExpression.sql(&arguments) + ")")
        }
        
        if let defaultExpression = defaultExpression {
            var arguments: StatementArguments? = nil // nil so that defaultExpression.sql(&arguments) embeds literals
            chunks.append("DEFAULT")
            chunks.append(defaultExpression.sql(&arguments))
        }
        
        if let collationName = collationName {
            chunks.append("COLLATE")
            chunks.append(collationName)
        }
        
        if let (table, column, deleteAction, updateAction, deferred) = reference {
            chunks.append("REFERENCES")
            if let column = column {
                chunks.append("\(table.quotedDatabaseIdentifier)(\(column.quotedDatabaseIdentifier))")
            } else if let primaryKey = try db.primaryKey(table) {
                chunks.append("\(table.quotedDatabaseIdentifier)(\((primaryKey.columns.map { $0.quotedDatabaseIdentifier } as [String]).joinWithSeparator(", ")))")
            } else {
                fatalError("explicit referenced column required, since table \(table) has no primary key")
            }
            if let deleteAction = deleteAction {
                chunks.append("ON DELETE")
                chunks.append(deleteAction.rawValue)
            }
            if let updateAction = updateAction {
                chunks.append("ON UPDATE")
                chunks.append(updateAction.rawValue)
            }
            if deferred {
                chunks.append("DEFERRABLE INITIALLY DEFERRED")
            }
        }
        
        return chunks.joinWithSeparator(" ")
    }
}

struct IndexBuilder {
    let name: String
    let table: String
    let columns: [String]
    let unique: Bool
    let ifNotExists: Bool
    let condition: _SQLExpression?
    
    func sql() -> String {
        var chunks: [String] = []
        chunks.append("CREATE")
        if unique {
            chunks.append("UNIQUE")
        }
        chunks.append("INDEX")
        if ifNotExists {
            chunks.append("IF NOT EXISTS")
        }
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append("ON")
        chunks.append("\(table.quotedDatabaseIdentifier)(\((columns.map { $0.quotedDatabaseIdentifier } as [String]).joinWithSeparator(", ")))")
        if let condition = condition {
            chunks.append("WHERE")
            var arguments: StatementArguments? = nil // nil so that checkExpression.sql(&arguments) embeds literals
            chunks.append(condition.sql(&arguments))
        }
        return chunks.joinWithSeparator(" ")
    }
}
