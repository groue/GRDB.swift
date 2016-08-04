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
    var primaryKeyBuilder: SQLPrimaryKeyBuilder?
    
    init(name: String, type: SQLColumnType) {
        self.name = name
        self.type = type
    }
    
    public func primaryKey(ordering ordering: SQLPrimaryKeyOrdering? = nil, onConflict conflictResolution: SQLConflictResolution? = nil, autoincrement: Bool = false) {
        primaryKeyBuilder = SQLPrimaryKeyBuilder(ordering: ordering, conflictResolution: conflictResolution, autoincrement: autoincrement)
    }
    
    var sql: String {
        var chunks: [String] = []
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append(type.rawValue)
        if let primaryKeyBuilder = primaryKeyBuilder {
            chunks.append(primaryKeyBuilder.sql)
        }
        return chunks.joinWithSeparator(" ")
    }
}

struct SQLPrimaryKeyBuilder {
    let ordering: SQLPrimaryKeyOrdering?
    let conflictResolution: SQLConflictResolution?
    let autoincrement: Bool
    
    var sql: String {
        var chunks: [String] = []
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
        return chunks.joinWithSeparator(" ")
    }
}

public enum SQLPrimaryKeyOrdering : String {
    case Asc = "ASC"
    case Desc = "DESC"
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
