extension Row {
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, _ request: Request) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Any { preconditionFailure() }
}

extension DatabaseValueConvertible {
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, _ request: Request) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Any { preconditionFailure() }
}

extension Optional where Wrapped: DatabaseValueConvertible {
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, _ request: Request) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Any { preconditionFailure() }
}

extension QueryInterfaceRequest {
    @available(*, unavailable, renamed:"fetchCursor")
    public func fetch(_ db: Database) -> Any { preconditionFailure() }
}

extension RowConvertible {
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, _ request: Request) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, _ sql: String, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) -> Any { preconditionFailure() }
}

extension RowConvertible where Self: TableMapping {
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database) -> Any { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch<Sequence: Swift.Sequence>(_ db: Database, keys: Sequence) -> Any where Sequence.Iterator.Element: DatabaseValueConvertible { preconditionFailure() }
    @available(*, unavailable, renamed:"fetchCursor")
    public static func fetch(_ db: Database, keys: [[String: DatabaseValueConvertible?]]) -> Any { preconditionFailure() }
}

@available(*, unavailable, message:"DatabaseSequence has been replaced by Cursor.")
public struct DatabaseSequence<T> { }

@available(*, unavailable, message:"DatabaseIterator has been replaced by Cursor.")
public struct DatabaseIterator<T> { }
