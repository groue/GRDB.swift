extension Database {
    @available(*, unavailable, renamed:"inTransaction")
    public func writeInTransaction(_ kind: Database.TransactionKind? = nil, _ block: (Database) throws -> Database.TransactionCompletion) throws { }
}

extension DatabaseValue {
    @available(*, unavailable, message:"DatabaseSequence has been replaced by Cursor.")
    public func value() -> Any { preconditionFailure() }
}
