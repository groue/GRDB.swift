/// The protocol for all types that define a way to fetch values from
/// a database.
public protocol FetchRequest {
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?)
}


struct SQLFetchRequest : FetchRequest {
    let sql: String
    let arguments: StatementArguments?
    let adapter: RowAdapter?
    
    init(sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) {
        self.sql = sql
        self.arguments = arguments
        self.adapter = adapter
    }
    
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let statement = try db.makeSelectStatement(sql)
        if let arguments = arguments {
            try statement.setArgumentsWithValidation(arguments)
        }
        return (statement, adapter)
    }
}
