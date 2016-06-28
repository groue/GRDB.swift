/// The protocol for all types that define a way to fetch values from
/// a database.
public protocol FetchRequest {
    /// A prepared statement that is ready to be executed.
    func selectStatement(db: Database) throws -> SelectStatement

    /// An eventual RowAdapter
    func adapter(statement: SelectStatement) throws -> RowAdapter?
}


struct SQLFetchRequest {
    let sql: String
    let arguments: StatementArguments?
    let adapter: RowAdapter?
    
    init(sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) {
        self.sql = sql
        self.arguments = arguments
        self.adapter = adapter
    }
}


extension SQLFetchRequest : FetchRequest {
    func selectStatement(db: Database) throws -> SelectStatement {
        let statement = try db.selectStatement(sql)
        if let arguments = arguments {
            try statement.setArgumentsWithValidation(arguments)
        }
        return statement
    }
    
    func adapter(statement: SelectStatement) throws -> RowAdapter? {
        return adapter
    }
}
