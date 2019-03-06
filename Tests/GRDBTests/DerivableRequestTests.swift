import XCTest
#if GRDBCIPHER
import GRDBCipher
#elseif GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

private struct Author: FetchableRecord, PersistableRecord, Codable {
    var id: Int64
    var firstName: String?
    var lastName: String?
    var country: String
    var fullName: String {
        return [firstName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    
    static let databaseTableName = "author"
    static let books = hasMany(Book.self)
    var books: QueryInterfaceRequest<Book> {
        return request(for: Author.books)
    }
}
private struct Book: FetchableRecord, PersistableRecord, Codable {
    var id: Int64
    var authorId: Int64
    var title: String
    
    static let databaseTableName = "book"
    static let author = belongsTo(Author.self)
    var author: QueryInterfaceRequest<Author> {
        return request(for: Book.author)
    }
}

private var libraryMigrator: DatabaseMigrator = {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("library") { db in
        try db.create(table: "author") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("firstName", .text)
            t.column("lastName", .text)
            t.column("country", .text).notNull()
        }
        try db.create(table: "book") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("authorId", .integer).notNull().references("author")
            t.column("title", .text).notNull()
        }
    }
    migrator.registerMigration("fixture") { db in
        try Author(id: 1, firstName: "Herman", lastName: "Melville", country: "US").insert(db)
        try Author(id: 2, firstName: "Marcel", lastName: "Proust", country: "FR").insert(db)
        try Book(id: 1, authorId: 1, title: "Moby-Dick").insert(db)
        try Book(id: 2, authorId: 2, title: "Du côté de chez Swann").insert(db)
    }
    return migrator
}()

// One extension...
extension DerivableRequest where RowDecoder == Author {
    func filter(country: String) -> Self {
        return filter(Column("country") == country)
    }
    
    func orderByFullName() -> Self {
        return order(
            Column("lastName").collating(.localizedCaseInsensitiveCompare),
            Column("firstName").collating(.localizedCaseInsensitiveCompare))
    }
}

class DerivableRequestTests: GRDBTestCase {
    func testFilter() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            // ... for two requests (1)
            let frenchAuthorNames = try Author.all()
                .filter(country: "FR")
                .fetchAll(db)
                .map { $0.fullName }
            XCTAssertEqual(frenchAuthorNames, ["Marcel Proust"])
            
            // ... for two requests (2)
            let frenchBookTitles = try Book
                .joining(required: Book.author.filter(country: "FR"))
                .order(Column("title"))
                .fetchAll(db)
                .map { $0.title }
            XCTAssertEqual(frenchBookTitles, ["Du côté de chez Swann"])
        }
    }
    
    func testOrder() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            // ... for two requests (1)
            let authorNames = try Author.all()
                .orderByFullName()
                .fetchAll(db)
                .map { $0.fullName }
            XCTAssertEqual(authorNames, ["Herman Melville", "Marcel Proust"])
            
            let reversedAuthorNames = try Author.all()
                .orderByFullName()
                .reversed()
                .fetchAll(db)
                .map { $0.fullName }
            XCTAssertEqual(reversedAuthorNames, ["Marcel Proust", "Herman Melville"])

            // ... for two requests (2)
            let bookTitles = try Book
                .joining(required: Book.author.orderByFullName())
                .fetchAll(db)
                .map { $0.title }
            XCTAssertEqual(bookTitles, ["Moby-Dick", "Du côté de chez Swann"])
            
            let reversedBookTitles = try Book
                .joining(required: Book.author.orderByFullName())
                .reversed()
                .fetchAll(db)
                .map { $0.title }
            XCTAssertEqual(reversedBookTitles, ["Du côté de chez Swann", "Moby-Dick"])
        }
    }
}
