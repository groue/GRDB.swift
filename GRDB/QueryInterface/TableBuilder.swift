public class SQLTableBuilder {
    let name: String
    var columns: [SQLColumnBuilder] = []
    
    init(name: String) {
        self.name = name
    }
    
    public func column(name: String, _ type: SQLColumnType) -> SQLColumnBuilder {
        let column = SQLColumnBuilder(name: name, type: type)
        columns.append(column)
        return column
    }
    
    var sql: String {
        var chunks: [String] = []
        chunks.append("CREATE")
        chunks.append("TABLE")
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append("(" + columns.map { $0.sql }.joinWithSeparator(", ") + ")")
        return chunks.joinWithSeparator(" ")
    }
}

public class SQLColumnBuilder {
    let name: String
    let type: SQLColumnType
    var isPrimaryKey: Bool = false
    
    init(name: String, type: SQLColumnType) {
        self.name = name
        self.type = type
    }
    
    public func primaryKey() {
        isPrimaryKey = true
    }
    
    var sql: String {
        var chunks: [String] = []
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append(type.rawValue)
        if isPrimaryKey {
            chunks.append("PRIMARY KEY")
        }
        return chunks.joinWithSeparator(" ")
    }
}

public enum SQLColumnType: String {
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
    public func create(table name: String, body: (SQLTableBuilder) -> Void) throws {
        let builder = SQLTableBuilder(name: name)
        body(builder)
        try execute(builder.sql)
    }
}
