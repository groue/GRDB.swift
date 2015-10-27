/// Represents the various changes made to the database via execution of one or
/// more SQL statements.
public struct DatabaseChanges {
    
    /// The number of rows affected by the statement(s)
    public let changedRowCount: Int
    
    /// The inserted Row ID.
    ///
    /// This value is only relevant after the execution of a single INSERT
    /// statement, via Database.execute() or UpdateStatement.execute().
    public let insertedRowID: Int64?
}
