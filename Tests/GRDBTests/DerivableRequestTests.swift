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
    var name: String
    var country: String
    
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
            t.column("name", .text).notNull()
            t.column("country", .text).notNull()
        }
        try db.create(table: "book") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("authorId", .integer).notNull().references("author")
            t.column("title", .text).notNull()
        }
    }
    migrator.registerMigration("fixture") { db in
        try Author(id: 1, name: "Melville", country: "US").insert(db)
        try Author(id: 2, name: "Proust", country: "FR").insert(db)
        try Book(id: 1, authorId: 1, title: "Moby-Dick").insert(db)
        try Book(id: 2, authorId: 2, title: "Du côté de chez Swann").insert(db)
        try Book(id: 3, authorId: 2, title: "Le Côté de Guermantes").insert(db)
    }
    return migrator
}()

// One extension...
extension DerivableRequest where RowDecoder == Author {
    func filter(country: String) -> Self {
        return filter(Column("country") == country)
    }
}

class DerivableRequestTests: GRDBTestCase {
    func testDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            // ... for two requests (1)
            let frenchAuthorNames = try Author.all()
                .filter(country: "FR")
                .fetchAll(db)
                .map { $0.name }
            XCTAssertEqual(frenchAuthorNames, ["Proust"])
            
            // ... for two requests (2)
            let frenchBookTitles = try Book
                .joining(required: Book.author.filter(country: "FR"))
                .order(Column("title"))
                .fetchAll(db)
                .map { $0.title }
            XCTAssertEqual(frenchBookTitles, ["Du côté de chez Swann", "Le Côté de Guermantes"])
        }
    }
}
