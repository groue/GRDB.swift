extension Database {
    @available(*, unavailable, renamed:"inTransaction")
    public func writeInTransaction(_ kind: Database.TransactionKind? = nil, _ block: (Database) throws -> Database.TransactionCompletion) throws { }
}
