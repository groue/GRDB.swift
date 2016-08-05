public class SQLTableBuilder {
    let name: String
    let temporary: Bool
    let ifNotExists: Bool
    let withoutRowID: Bool
    var columns: [SQLColumnBuilder] = []
    var primaryKeyConstraint: (columns: [String], conflictResolution: SQLConflictResolution?)?
    var uniqueKeyConstraints: [(columns: [String], conflictResolution: SQLConflictResolution?)] = []
    var foreignKeyConstraints: [(columns: [String], table: String, destinationColumns: [String]?, deleteAction: SQLForeignKeyAction?, updateAction: SQLForeignKeyAction?, deferred: Bool)] = []
    
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
    public func foreignKey(columns: [String], to table: String, columns destinationColumns: [String]? = nil, onDelete deleteAction: SQLForeignKeyAction? = nil, onUpdate updateAction: SQLForeignKeyAction? = nil, deferred: Bool = false) {
        foreignKeyConstraints.append((columns: columns, table: table, destinationColumns: destinationColumns, deleteAction: deleteAction, updateAction: updateAction, deferred: deferred))
    }
    
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
            
            chunks.append("(\(items.joinWithSeparator(", ")))")
        }
        
        if withoutRowID {
            chunks.append("WITHOUT ROWID")
        }
        return chunks.joinWithSeparator(" ")
    }
}

public class SQLColumnBuilder {
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
    public func primaryKey(ordering ordering: SQLOrdering? = nil, onConflict conflictResolution: SQLConflictResolution? = nil, autoincrement: Bool = false) {
        primaryKey = (ordering: ordering, conflictResolution: conflictResolution, autoincrement: autoincrement)
    }
    
    // TODO: doc
    public func notNull(onConflict conflictResolution: SQLConflictResolution? = nil) {
        notNullConflictResolution = conflictResolution ?? .Abort
    }
    
    // TODO: doc
    public func unique(onConflict conflictResolution: SQLConflictResolution? = nil) {
        uniqueConflictResolution = conflictResolution ?? .Abort
    }
    
    // TODO: doc
    public func check(@noescape condition: (SQLColumn) -> _SQLExpressible) {
        checkExpression = condition(SQLColumn(name)).sqlExpression
    }
    
    // TODO: doc
    // TODO: defaults(sql: "CURRENT_TIMESTAMP")
    public func defaults(value: _SQLExpressible) {
        defaultExpression = value.sqlExpression
    }
    
    // TODO: doc
    public func collate(collation: SQLCollation) {
        collationName = collation.rawValue
    }
    
    // TODO: doc
    public func collate(collation: DatabaseCollation) {
        collationName = collation.name
    }
    
    // TODO: doc
    public func references(table: String, column: String? = nil, onDelete deleteAction: SQLForeignKeyAction? = nil, onUpdate updateAction: SQLForeignKeyAction? = nil, deferred: Bool = false) {
        reference = (table: table, column: column, deleteAction: deleteAction, updateAction: updateAction, deferred: deferred)
    }
    
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
            var arguments: StatementArguments? = nil // nil so that checkExpression.sql(&arguments) embeds literals
            chunks.append("CHECK")
            chunks.append("(" + checkExpression.sql(&arguments) + ")")
        }
        
        if let defaultExpression = defaultExpression {
            var arguments: StatementArguments? = nil // nil so that defaultExpression.sql(&arguments) embeds literals
            chunks.append("DEFAULT")
            chunks.append("(" + defaultExpression.sql(&arguments) + ")")
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

extension Database {
    // TODO: doc
    // TODO: Don't expose withoutRowID if not available
    public func create(table name: String, temporary: Bool = false, ifNotExists: Bool = false, withoutRowID: Bool = false, body: (SQLTableBuilder) -> Void) throws {
        let builder = SQLTableBuilder(name: name, temporary: temporary, ifNotExists: ifNotExists, withoutRowID: withoutRowID)
        body(builder)
        let sql = try builder.sql(self)
        try execute(sql)
    }
    
    // TODO: doc
    public func drop(table name: String) throws {
        try execute("DROP TABLE \(name.quotedDatabaseIdentifier)")
    }
}
