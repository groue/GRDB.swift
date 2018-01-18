#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// GRDB 1.2 has shipped with a change in the DatabaseReader public protocol.
//
// This change in a public protocol has broken the semantic versioning contract,
// because userland types that adopt the protocol suddenly stop compiling. And
// indeed RxGRDB had to be modified in order to accomodate GRDB 1.2.
//
// To prevent such breaking change, this file contains types that adopt all GRBD
// public protocols, but experimental ones. Test pass if this file compiles
// without any error.

// MARK: - Cursor

private class UserCursor<T> : Cursor {
    func next() throws -> T? { preconditionFailure() }
}

extension UserCursor {
    // Test presence of the Element associated type
    static var elementType: Element.Type { return Element.self }
}

// MARK: - DatabaseAggregate

private struct UserDatabaseAggregate1 : DatabaseAggregate {
    let a: Int?
    init() { a = nil }
    mutating func step(_ dbValues: [DatabaseValue]) throws { }
    func finalize() throws -> DatabaseValueConvertible? { preconditionFailure() }
}

private class UserDatabaseAggregate2 : DatabaseAggregate {
    required init() { }
    func step(_ dbValues: [DatabaseValue]) throws { }
    func finalize() throws -> DatabaseValueConvertible? { preconditionFailure() }
}

// MARK: - DatabaseReader

private class UserDatabaseReader : DatabaseReader {
    func read<T>(_ block: (Database) throws -> T) throws -> T { preconditionFailure() }
    func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T { preconditionFailure() }
    func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T { preconditionFailure() }
    func add(function: DatabaseFunction) { }
    func remove(function: DatabaseFunction) { }
    func add(collation: DatabaseCollation) { }
    func remove(collation: DatabaseCollation) { }
}

// MARK: - DatabaseValueConvertible

private struct UserDatabaseValueConvertible1 : DatabaseValueConvertible {
    var databaseValue: DatabaseValue { preconditionFailure() }
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> UserDatabaseValueConvertible1? { preconditionFailure() }
}

private class UserDatabaseValueConvertible2 : DatabaseValueConvertible {
    var databaseValue: DatabaseValue { preconditionFailure() }
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? { preconditionFailure() }
}

// MARK: - DatabaseWriter

private class UserDatabaseWriter : DatabaseWriter {
    func read<T>(_ block: (Database) throws -> T) throws -> T { preconditionFailure() }
    func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T { preconditionFailure() }
    func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T { preconditionFailure() }
    func add(function: DatabaseFunction) { }
    func remove(function: DatabaseFunction) { }
    func add(collation: DatabaseCollation) { }
    func remove(collation: DatabaseCollation) { }
    func write<T>(_ block: (Database) throws -> T) rethrows -> T { preconditionFailure() }
    func unsafeReentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T { preconditionFailure() }
    func readFromCurrentState(_ block: @escaping (Database) -> Void) throws { preconditionFailure() }
}

// MARK: - FTS5Tokenizer

#if SQLITE_ENABLE_FTS5
private class UserFTS5Tokenizer : FTS5Tokenizer {
    func tokenize(context: UnsafeMutableRawPointer?, tokenization: FTS5Tokenization, pText: UnsafePointer<Int8>?, nText: Int32, tokenCallback: @escaping FTS5TokenCallback) -> Int32 { preconditionFailure() }
}
#endif

// MARK: - FTS5CustomTokenizer

#if SQLITE_ENABLE_FTS5
private class UserFTS5CustomTokenizer : FTS5CustomTokenizer {
    static let name: String = "UserFTS5CustomTokenizer"
    required init(db: Database, arguments: [String]) throws { preconditionFailure() }
    func tokenize(context: UnsafeMutableRawPointer?, tokenization: FTS5Tokenization, pText: UnsafePointer<Int8>?, nText: Int32, tokenCallback: @escaping FTS5TokenCallback) -> Int32 { preconditionFailure() }
}
#endif

// MARK: - FTS5WrapperTokenizer

#if SQLITE_ENABLE_FTS5
private class UserFTS5WrapperTokenizer : FTS5WrapperTokenizer {
    static let name: String = "UserFTS5WrapperTokenizer"
    var wrappedTokenizer: FTS5Tokenizer { preconditionFailure() }
    required init(db: Database, arguments: [String]) throws { preconditionFailure() }
    func accept(token: String, flags: FTS5TokenFlags, for tokenization: FTS5Tokenization, tokenCallback: (String, FTS5TokenFlags) throws -> ()) throws { preconditionFailure() }
}
#endif

// MARK: - MutablePersistable

private struct UserMutablePersistable1 : MutablePersistable {
    static let databaseTableName = "UserMutablePersistable1"
    func encode(to container: inout PersistenceContainer) { }
}

private class UserMutablePersistable2 : MutablePersistable {
    static let databaseTableName = "UserMutablePersistable2"
    func encode(to container: inout PersistenceContainer) { }
}

// MARK: - Persistable

private struct UserPersistable1 : Persistable {
    static let databaseTableName = "UserPersistable1"
    func encode(to container: inout PersistenceContainer) { }
}

private class UserPersistable2 : Persistable {
    static let databaseTableName = "UserPersistable2"
    func encode(to container: inout PersistenceContainer) { }
}

// MARK: - Request

private struct UserRequest1 : Request {
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) { preconditionFailure() }
}

private class UserRequest2 : Request {
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) { preconditionFailure() }
}

// MARK: - RowConvertible

private struct UserRowConvertible1 : RowConvertible {
    init(row: Row) { }
}

private class UserRowConvertible2 : RowConvertible {
    required init(row: Row) { }
}

// MARK: - StatementColumnConvertible

private struct UserStatementColumnConvertible1 : StatementColumnConvertible {
    init(sqliteStatement: SQLiteStatement, index: Int32) { }
}

private class UserStatementColumnConvertible2 : StatementColumnConvertible {
    required init(sqliteStatement: SQLiteStatement, index: Int32) { }
}

// MARK: - TableMapping

private struct UserTableMapping1 : TableMapping {
    static let databaseTableName = "UserTableMapping1"
}

private class UserTableMapping2 : TableMapping {
    static let databaseTableName = "UserTableMapping2"
}

// MARK: - TypedRequest

private struct UserTypedRequest1 : TypedRequest {
    struct CustomType { }
    typealias RowDecoder = CustomType
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) { preconditionFailure() }
}

private class UserTypedRequest2<T> : TypedRequest {
    typealias RowDecoder = T
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) { preconditionFailure() }
}

// MARK: - TransactionObserver

private class UserTransactionObserver : TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { return false }
    func databaseDidChange(with event: DatabaseEvent) { }
    func databaseDidCommit(_ db: Database) { }
    func databaseDidRollback(_ db: Database) { }
}

// MARK: - VirtualTableModule

private struct UserVirtualTableModule1 : VirtualTableModule {
    struct CustomTableDefinition { }
    let moduleName = "UserVirtualTableModule1"
    func makeTableDefinition() -> CustomTableDefinition { preconditionFailure() }
    func moduleArguments(for definition: CustomTableDefinition, in db: Database) throws -> [String] { preconditionFailure() }
    func database(_ db: Database, didCreate tableName: String, using definition: CustomTableDefinition) throws { }
}

private class UserVirtualTableModule2 : VirtualTableModule {
    struct CustomTableDefinition { }
    let moduleName = "UserVirtualTableModule2"
    func makeTableDefinition() -> CustomTableDefinition { preconditionFailure() }
    func moduleArguments(for definition: CustomTableDefinition, in db: Database) throws -> [String] { preconditionFailure() }
    func database(_ db: Database, didCreate tableName: String, using definition: CustomTableDefinition) throws { }
}
