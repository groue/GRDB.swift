import GRDB

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
    static var elementType: Element.Type { Element.self }
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

// MARK: - DatabaseValueConvertible

private struct UserDatabaseValueConvertible1 : DatabaseValueConvertible {
    var databaseValue: DatabaseValue { preconditionFailure() }
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> UserDatabaseValueConvertible1? { preconditionFailure() }
}

private class UserDatabaseValueConvertible2 : DatabaseValueConvertible {
    var databaseValue: DatabaseValue { preconditionFailure() }
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? { preconditionFailure() }
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

// MARK: - MutablePersistableRecord

private struct UserMutablePersistableRecord1 : MutablePersistableRecord {
    static let databaseTableName = "UserMutablePersistableRecord1"
    func encode(to container: inout PersistenceContainer) { }
}

private class UserMutablePersistableRecord2 : MutablePersistableRecord {
    static let databaseTableName = "UserMutablePersistableRecord2"
    func encode(to container: inout PersistenceContainer) { }
}

// MARK: - PersistableRecord

private struct UserPersistableRecord1 : PersistableRecord {
    static let databaseTableName = "UserPersistableRecord1"
    func encode(to container: inout PersistenceContainer) { }
}

private class UserPersistableRecord2 : PersistableRecord {
    static let databaseTableName = "UserPersistableRecord2"
    func encode(to container: inout PersistenceContainer) { }
}

// MARK: - FetchableRecord

private struct UserFetchableRecord1 : FetchableRecord {
    init(row: Row) throws { }
}

private class UserFetchableRecord2 : FetchableRecord {
    required init(row: Row) throws { }
}

// MARK: - StatementColumnConvertible

private struct UserStatementColumnConvertible1 : StatementColumnConvertible {
    init?(sqliteStatement: SQLiteStatement, index: Int32) { }
}

private struct UserStatementColumnConvertible2 : StatementColumnConvertible {
    init(sqliteStatement: SQLiteStatement, index: Int32) { }
}

private class UserStatementColumnConvertible3 : StatementColumnConvertible {
    required init?(sqliteStatement: SQLiteStatement, index: Int32) { }
}

private class UserStatementColumnConvertible4 : StatementColumnConvertible {
    required init(sqliteStatement: SQLiteStatement, index: Int32) { }
}

// MARK: - TableRecord

private struct UserTableRecord1 : TableRecord {
    static let databaseTableName = "UserTableRecord1"
}

private class UserTableRecord2 : TableRecord {
    static let databaseTableName = "UserTableRecord2"
}

// MARK: - TransactionObserver

private class UserTransactionObserver : TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { false }
    func databaseDidChange(with event: DatabaseEvent) { }
    func databaseDidCommit(_ db: Database) { }
    func databaseDidRollback(_ db: Database) { }
}

// MARK: - VirtualTableModule

private struct UserVirtualTableModule1 : VirtualTableModule {
    struct CustomTableDefinition { }
    let moduleName = "UserVirtualTableModule1"
    func makeTableDefinition(configuration: VirtualTableConfiguration) -> CustomTableDefinition { preconditionFailure() }
    func moduleArguments(for definition: CustomTableDefinition, in db: Database) throws -> [String] { preconditionFailure() }
    func database(_ db: Database, didCreate tableName: String, using definition: CustomTableDefinition) throws { }
}

private class UserVirtualTableModule2 : VirtualTableModule {
    struct CustomTableDefinition { }
    let moduleName = "UserVirtualTableModule2"
    func makeTableDefinition(configuration: VirtualTableConfiguration) -> CustomTableDefinition { preconditionFailure() }
    func moduleArguments(for definition: CustomTableDefinition, in db: Database) throws -> [String] { preconditionFailure() }
    func database(_ db: Database, didCreate tableName: String, using definition: CustomTableDefinition) throws { }
}
