public class SQLTableBuilder {
    let name: String
    let temporary: Bool
    let ifNotExists: Bool
    let withoutRowID: Bool
    var columns: [SQLColumnBuilder] = []
    
    init(name: String, temporary: Bool, ifNotExists: Bool, withoutRowID: Bool) {
        self.name = name
        self.temporary = temporary
        self.ifNotExists = ifNotExists
        self.withoutRowID = withoutRowID
    }
    
    public func column(name: String, _ type: SQLColumnType) -> SQLColumnBuilder {
        let column = SQLColumnBuilder(name: name, type: type)
        columns.append(column)
        return column
    }
    
    var sql: String {
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
        chunks.append("(" + columns.map { $0.sql }.joinWithSeparator(", ") + ")")
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
    
    init(name: String, type: SQLColumnType) {
        self.name = name
        self.type = type
    }
    
    public func primaryKey(ordering ordering: SQLOrdering? = nil, onConflict conflictResolution: SQLConflictResolution? = nil, autoincrement: Bool = false) {
        primaryKey = (ordering: ordering, conflictResolution: conflictResolution, autoincrement: autoincrement)
    }
    
    public func notNull(onConflict conflictResolution: SQLConflictResolution? = nil) {
        notNullConflictResolution = conflictResolution ?? .Abort
    }
    
    public func unique(onConflict conflictResolution: SQLConflictResolution? = nil) {
        uniqueConflictResolution = conflictResolution ?? .Abort
    }
    
    public func check(@noescape condition: (SQLColumn) -> _SQLExpressible) {
        checkExpression = condition(SQLColumn(name)).sqlExpression
    }
    
    public func defaults(value: _SQLExpressible) {
        defaultExpression = value.sqlExpression
    }
    
    public func collate(collation: SQLCollation) {
        collationName = collation.rawValue
    }
    
    public func collate(collation: DatabaseCollation) {
        collationName = collation.name
    }
    
    var sql: String {
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
            var arguments: StatementArguments? = nil // nil so that checkExpression.sql(&arguments) embeds literals
            chunks.append("DEFAULT")
            chunks.append("(" + defaultExpression.sql(&arguments) + ")")
        }
        
        if let collationName = collationName {
            chunks.append("COLLATE")
            chunks.append(collationName)
        }
        
        return chunks.joinWithSeparator(" ")
    }
}

public enum SQLOrdering : String {
    case Asc = "ASC"
    case Desc = "DESC"
}

public enum SQLCollation : String {
    case Binary = "BINARY"
    case Nocase = "NOCASE"
    case Rtrim = "RTRIM"
}

public enum SQLConflictResolution : String {
    case Rollback = "ROLLBACK"
    case Abort = "ABORT"
    case Fail = "FAIL"
    case Ignore = "IGNORE"
    case Replace = "REPLACE"
}

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

extension Database {
    // TODO: doc
    // TODO: Don't expose withoutRowID if not available
    public func create(table name: String, temporary: Bool = false, ifNotExists: Bool = false, withoutRowID: Bool = false, body: (SQLTableBuilder) -> Void) throws {
        let builder = SQLTableBuilder(name: name, temporary: temporary, ifNotExists: ifNotExists, withoutRowID: withoutRowID)
        body(builder)
        try execute(builder.sql)
    }
    
    // TODO: doc
    public func drop(table name: String) throws {
        try execute("DROP TABLE \(name.quotedDatabaseIdentifier)")
    }
}
