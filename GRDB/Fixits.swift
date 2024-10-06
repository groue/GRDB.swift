// Fixits for changes introduced by GRDB 7.0.0
// swiftlint:disable all

extension Configuration {
    @available(*, unavailable, message: "The default transaction kind is now automatically managed.")
    public var defaultTransactionKind: Database.TransactionKind {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
}

@available(*, unavailable, message: "DatabaseFuture has been removed.")
public class DatabaseFuture<Value> { }

extension DatabasePool {
    @available(*, unavailable, message: "concurrentRead has been removed. Use `asyncConcurrentRead` instead.")
    public func concurrentRead<T>(_ value: @escaping (Database) throws -> T) -> DatabaseFuture<T> { preconditionFailure() }
}

// swiftlint:enable all
