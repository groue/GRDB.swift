import XCTest
import GRDB

private struct Author: FetchableRecord, PersistableRecord, Codable {
    var id: Int64
    var firstName: String?
    var lastName: String?
    var country: String
    var fullName: String {
        [firstName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    
    static let databaseTableName = "author"
    static let books = hasMany(Book.self)
    
    var books: QueryInterfaceRequest<Book> { request(for: Author.books) }
}

private struct Book: FetchableRecord, PersistableRecord, Codable {
    var id: Int64
    var authorId: Int64
    var title: String
    
    static let databaseTableName = "book"
    static let author = belongsTo(Author.self)
    static let bookFts4 = hasOne(BookFts4.self, using: ForeignKey([.rowID]))
    #if SQLITE_ENABLE_FTS5
    static let bookFts5 = hasOne(BookFts5.self, using: ForeignKey([.rowID]))
    #endif
    
    var author: QueryInterfaceRequest<Author> { request(for: Book.author) }
}

private struct BookFts4: TableRecord { }

#if SQLITE_ENABLE_FTS5
private struct BookFts5: TableRecord { }
#endif

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
            t.belongsTo("author").notNull()
            t.column("title", .text).notNull()
        }
        try db.create(virtualTable: "bookFts4", using: FTS4()) { t in
            t.synchronize(withTable: "book")
            t.column("title")
        }
        #if SQLITE_ENABLE_FTS5
        try db.create(virtualTable: "bookFts5", using: FTS5()) { t in
            t.synchronize(withTable: "book")
            t.column("title")
        }
        #endif
    }
    migrator.registerMigration("fixture") { db in
        try Author(id: 1, firstName: "Herman", lastName: "Melville", country: "US").insert(db)
        try Author(id: 2, firstName: "Marcel", lastName: "Proust", country: "FR").insert(db)
        try Book(id: 1, authorId: 1, title: "Moby-Dick").insert(db)
        try Book(id: 2, authorId: 2, title: "Du côté de chez Swann").insert(db)
    }
    return migrator
}()

// Define DerivableRequest extensions
extension DerivableRequest<Author> {
    // SelectionRequest
    func selectCountry() -> Self {
        select(Column("country"))
    }
    
    // FilteredRequest
    func filter(country: String) -> Self {
        filter(Column("country") == country)
    }
    
    // OrderedRequest
    func orderByFullName() -> Self {
        order(
            Column("lastName").collating(.localizedCaseInsensitiveCompare),
            Column("firstName").collating(.localizedCaseInsensitiveCompare))
    }
}

extension DerivableRequest<Book> {
    // OrderedRequest
    func orderByTitle() -> Self {
        order(Column("title").collating(.localizedCaseInsensitiveCompare))
    }
    
    // JoinableRequest
    func filter(authorCountry: String) -> Self {
        joining(required: Book.author.filter(country: authorCountry))
    }
    
    // TableRequest & FilteredRequest
    func filter(id: Int) -> Self { filter(key: id) }
    
    // TableRequest & FilteredRequest
    func matchingFts4(_ pattern: FTS3Pattern?) -> Self {
        joining(required: Book.bookFts4.matching(pattern))
    }
    
    #if SQLITE_ENABLE_FTS5
    // TableRequest & FilteredRequest
    func matchingFts5(_ pattern: FTS3Pattern?) -> Self {
        joining(required: Book.bookFts5.matching(pattern))
    }
    #endif
    
    // TableRequest & OrderedRequest
    func orderById() -> Self { orderByPrimaryKey() }
}

class DerivableRequestTests: GRDBTestCase {
    func testAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            let baseRequest = Author.all().filter(country: "FR")
            let request = baseRequest.all()
            let (sql, arguments) = try request.build(db)
            XCTAssertEqual(sql, #"SELECT * FROM "author" WHERE "country" = ?"#)
            XCTAssertEqual(arguments, ["FR"])
        }
    }
    
    func testNone() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            let baseRequest = Author.all().filter(country: "FR")
            let request = baseRequest.none()
            let (sql, arguments) = try request.build(db)
            XCTAssertEqual(sql, #"SELECT * FROM "author" WHERE ("country" = ?) AND ?"#)
            XCTAssertEqual(arguments, ["FR", false])
        }
    }
    
    func testFilteredRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            // ... for two requests (1)
            let frenchAuthorNames = try Author.all()
                .filter(country: "FR")
                .fetchAll(db)
                .map(\.fullName)
            XCTAssertEqual(frenchAuthorNames, ["Marcel Proust"])
            
            // ... for two requests (2)
            let frenchBookTitles = try Book
                .joining(required: Book.author.filter(country: "FR"))
                .order(Column("title"))
                .fetchAll(db)
                .map(\.title)
            XCTAssertEqual(frenchBookTitles, ["Du côté de chez Swann"])
        }
    }
    
    func testOrderedRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            try db.create(view: "authorView", as: Author.select(
                AllColumns(),
                [Column("firstName"), Column("lastName")]
                    .joined(operator: .concat)
                    .forKey("fullName")))
                          
            // ... for one table
            sqlQueries.removeAll()
            let authorNames = try Author.all()
                .orderByFullName()
                .fetchAll(db)
                .map(\.fullName)
            XCTAssertEqual(authorNames, ["Herman Melville", "Marcel Proust"])
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "author" \
                ORDER BY "lastName" COLLATE swiftLocalizedCaseInsensitiveCompare, \
                "firstName" COLLATE swiftLocalizedCaseInsensitiveCompare
                """)
            
            sqlQueries.removeAll()
            let reversedAuthorNames = try Author.all()
                .orderByFullName()
                .reversed()
                .fetchAll(db)
                .map(\.fullName)
            XCTAssertEqual(reversedAuthorNames, ["Marcel Proust", "Herman Melville"])
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "author" \
                ORDER BY "lastName" COLLATE swiftLocalizedCaseInsensitiveCompare DESC, \
                "firstName" COLLATE swiftLocalizedCaseInsensitiveCompare DESC
                """)
            
            sqlQueries.removeAll()
            _ /* unorderedAuthors */ = try Author.all()
                .orderByFullName()
                .unordered()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "author"
                """)
            
            sqlQueries.removeAll()
            _ /* stableOrderAuthors */ = try Author.all()
                .withStableOrder()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "author" ORDER BY "id"
                """)

            sqlQueries.removeAll()
            _ /* stableOrderAuthors */ = try Author.all()
                .orderByFullName()
                .withStableOrder()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "author" ORDER BY "lastName" COLLATE swiftLocalizedCaseInsensitiveCompare, "firstName" COLLATE swiftLocalizedCaseInsensitiveCompare, "id"
                """)
            
            // ... for one view
            sqlQueries.removeAll()
            _ /* authorViewNames */ = try Table("authorView").all()
                .order(Column("fullName"))
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "authorView" \
                ORDER BY "fullName"
                """)
            
            sqlQueries.removeAll()
            _ /* reversedAuthorViewNames */ = try Table("authorView").all()
                .order(Column("fullName"))
                .reversed()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "authorView" \
                ORDER BY "fullName" DESC
                """)
            
            sqlQueries.removeAll()
            _ /* unorderedAuthorViews */ = try Table("authorView").all()
                .order(Column("fullName"))
                .unordered()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "authorView"
                """)
            
            sqlQueries.removeAll()
            _ /* stableOrderAuthorViews */ = try Table("authorView").all()
                .withStableOrder()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "authorView" ORDER BY 1, 2, 3, 4, 5
                """)

            sqlQueries.removeAll()
            _ /* stableOrderAuthorViews */ = try Table("authorView").all()
                .order(Column("fullName"))
                .withStableOrder()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "authorView" ORDER BY "fullName", 1, 2, 3, 4, 5
                """)
            
            // ... for two tables (2)
            sqlQueries.removeAll()
            let bookTitles = try Book
                .joining(required: Book.author.orderByFullName())
                .orderByTitle()
                .fetchAll(db)
                .map(\.title)
            XCTAssertEqual(bookTitles, ["Du côté de chez Swann", "Moby-Dick"])
            XCTAssertEqual(lastSQLQuery, """
                SELECT "book".* FROM "book" \
                JOIN "author" ON "author"."id" = "book"."authorId" \
                ORDER BY \
                "book"."title" COLLATE swiftLocalizedCaseInsensitiveCompare, \
                "author"."lastName" COLLATE swiftLocalizedCaseInsensitiveCompare, \
                "author"."firstName" COLLATE swiftLocalizedCaseInsensitiveCompare
                """)
            
            sqlQueries.removeAll()
            let reversedBookTitles = try Book
                .joining(required: Book.author.orderByFullName())
                .orderByTitle()
                .reversed()
                .fetchAll(db)
                .map(\.title)
            XCTAssertEqual(reversedBookTitles, ["Moby-Dick", "Du côté de chez Swann"])
            XCTAssertEqual(lastSQLQuery, """
                SELECT "book".* FROM "book" \
                JOIN "author" ON "author"."id" = "book"."authorId" \
                ORDER BY \
                "book"."title" COLLATE swiftLocalizedCaseInsensitiveCompare DESC, \
                "author"."lastName" COLLATE swiftLocalizedCaseInsensitiveCompare DESC, \
                "author"."firstName" COLLATE swiftLocalizedCaseInsensitiveCompare DESC
                """)
            
            sqlQueries.removeAll()
            _ /* unorderedBooks */ = try Book
                .joining(required: Book.author.orderByFullName())
                .orderByTitle()
                .unordered()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT "book".* FROM "book" \
                JOIN "author" ON "author"."id" = "book"."authorId"
                """)
            
            sqlQueries.removeAll()
            _ /* stableOrderBooks */ = try Book
                .joining(required: Book.author.orderByFullName())
                .orderByTitle()
                .withStableOrder()
                .fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT "book".* FROM "book" \
                JOIN "author" ON "author"."id" = "book"."authorId" \
                ORDER BY \
                "book"."title" COLLATE swiftLocalizedCaseInsensitiveCompare, \
                "book"."id", \
                "author"."lastName" COLLATE swiftLocalizedCaseInsensitiveCompare, \
                "author"."firstName" COLLATE swiftLocalizedCaseInsensitiveCompare, \
                "author"."id"
                """)
        }
    }
    
    func testSelectionRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            do {
                sqlQueries.removeAll()
                let request = Author.all().selectCountry()
                let authorCountries = try Set(String.fetchAll(db, request))
                XCTAssertEqual(authorCountries, ["FR", "US"])
                XCTAssertEqual(lastSQLQuery, """
                    SELECT "country" FROM "author"
                    """)
            }
            
            do {
                sqlQueries.removeAll()
                let request = Book.including(required: Book.author.selectCountry())
                _ = try Row.fetchAll(db, request)
                XCTAssertEqual(lastSQLQuery, """
                    SELECT "book".*, "author"."country" \
                    FROM "book" \
                    JOIN "author" ON "author"."id" = "book"."authorId"
                    """)
            }
        }
    }
    
    func testJoinableRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            do {
                sqlQueries.removeAll()
                let frenchBookTitles = try Book.all()
                    .filter(authorCountry: "FR")
                    .order(Column("title"))
                    .fetchAll(db)
                    .map(\.title)
                XCTAssertEqual(frenchBookTitles, ["Du côté de chez Swann"])
                XCTAssertEqual(lastSQLQuery, """
                    SELECT "book".* \
                    FROM "book" \
                    JOIN "author" ON ("author"."id" = "book"."authorId") AND ("author"."country" = 'FR') \
                    ORDER BY "book"."title"
                    """)
            }
            
            do {
                sqlQueries.removeAll()
                let frenchAuthorFullNames = try Author
                    .joining(required: Author.books.filter(authorCountry: "FR"))
                    .order(Column("firstName"))
                    .fetchAll(db)
                    .map(\.fullName)
                XCTAssertEqual(frenchAuthorFullNames, ["Marcel Proust"])
                XCTAssertEqual(lastSQLQuery, """
                    SELECT "author1".* \
                    FROM "author" "author1" \
                    JOIN "book" ON "book"."authorId" = "author1"."id" \
                    JOIN "author" "author2" ON ("author2"."id" = "book"."authorId") AND ("author2"."country" = 'FR') \
                    ORDER BY "author1"."firstName"
                    """)
            }
        }
    }
    
    func testTableRequestFilteredRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try libraryMigrator.migrate(dbQueue)
        try dbQueue.inDatabase { db in
            // filter(id:)
            do {
                let title = try Book.all()
                    .filter(id: 2)
                    .fetchOne(db)
                    .map(\.title)
                XCTAssertEqual(title, "Du côté de chez Swann")
                XCTAssertEqual(lastSQLQuery, """
                    SELECT * FROM "book" WHERE "id" = 2
                    """)
                
                let fullName = try Author
                    .joining(required: Author.books.filter(id: 2))
                    .fetchOne(db)
                    .map(\.fullName)
                XCTAssertEqual(fullName, "Marcel Proust")
                XCTAssertEqual(lastSQLQuery, """
                    SELECT "author".* FROM "author" \
                    JOIN "book" ON ("book"."authorId" = "author"."id") AND ("book"."id" = 2) \
                    LIMIT 1
                    """)
            }
            
            // matchingFts4
            do {
                sqlQueries.removeAll()
                let title = try Book.all()
                    .matchingFts4(FTS3Pattern(rawPattern: "moby dick"))
                    .fetchOne(db)
                    .map(\.title)
                XCTAssertEqual(title, "Moby-Dick")
                XCTAssert(sqlQueries.contains("""
                    SELECT "book".* FROM "book" \
                    JOIN "bookFts4" ON ("bookFts4"."rowid" = "book"."id") AND ("bookFts4" MATCH 'moby dick') \
                    LIMIT 1
                    """))
                
                sqlQueries.removeAll()
                let fullName = try Author
                    .joining(required: Author.books.matchingFts4(FTS3Pattern(rawPattern: "moby dick")))
                    .fetchOne(db)
                    .map(\.fullName)
                XCTAssertEqual(fullName, "Herman Melville")
                XCTAssert(sqlQueries.contains("""
                    SELECT "author".* FROM "author" \
                    JOIN "book" ON "book"."authorId" = "author"."id" \
                    JOIN "bookFts4" ON ("bookFts4"."rowid" = "book"."id") AND ("bookFts4" MATCH 'moby dick') \
                    LIMIT 1
                    """))
            }
            
            #if SQLITE_ENABLE_FTS5
            // matchingFts5
            do {
                sqlQueries.removeAll()
                let title = try Book.all()
                    .matchingFts5(FTS3Pattern(rawPattern: "cote swann"))
                    .fetchOne(db)
                    .map(\.title)
                XCTAssertEqual(title, "Du côté de chez Swann")
                XCTAssert(sqlQueries.contains("""
                    SELECT "book".* FROM "book" \
                    JOIN "bookFts5" ON ("bookFts5"."rowid" = "book"."id") AND ("bookFts5" MATCH 'cote swann') \
                    LIMIT 1
                    """))
                
                sqlQueries.removeAll()
                let fullName = try Author
                    .joining(required: Author.books.matchingFts5(FTS3Pattern(rawPattern: "cote swann")))
                    .fetchOne(db)
                    .map(\.fullName)
                XCTAssertEqual(fullName, "Marcel Proust")
                XCTAssert(sqlQueries.contains("""
                    SELECT "author".* FROM "author" \
                    JOIN "book" ON "book"."authorId" = "author"."id" \
                    JOIN "bookFts5" ON ("bookFts5"."rowid" = "book"."id") AND ("bookFts5" MATCH 'cote swann') \
                    LIMIT 1
                    """))
            }
            #endif
            
            // orderById
            do {
                let titles = try Book.all()
                    .orderById()
                    .fetchAll(db)
                    .map(\.title)
                XCTAssertEqual(titles, ["Moby-Dick", "Du côté de chez Swann"])
                XCTAssertEqual(lastSQLQuery, """
                    SELECT * FROM "book" ORDER BY "id"
                    """)
                
                let fullNames = try Author
                    .joining(required: Author.books.orderById())
                    .fetchAll(db)
                    .map(\.fullName)
                XCTAssertEqual(fullNames, ["Herman Melville", "Marcel Proust"])
                XCTAssertEqual(lastSQLQuery, """
                    SELECT "author".* FROM "author" \
                    JOIN "book" ON "book"."authorId" = "author"."id" ORDER BY "book"."id"
                    """)
            }
        }
    }
}
