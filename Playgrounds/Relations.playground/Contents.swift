import GRDB

// Database setup

var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)

try! dbQueue.inDatabase { db in
    try db.create(table: "authors") { t in
        t.column("id", .Integer).primaryKey()
        t.column("name", .Text)
    }
    
    try db.create(table: "books") { t in
        t.column("id", .Integer).primaryKey()
        t.column("authorId", .Integer).references("authors") // relation column
        t.column("title", .Text)
    }
    
    try db.create(table: "persons") { t in
        t.column("id", .Integer).primaryKey()
        t.column("name", .Text)
        t.column("fatherId", .Integer).references("persons") // relation column
        t.column("motherId", .Integer).references("persons") // relation column
    }
    
}

// Record definition

class Author : Record {
    var id: Int64?
    var name: String
    
    init(name: String) {
        self.name = name
        super.init()
    }
    
    // Books relation
    static let books = Relation(to: "books", columns: ["authorId"])
    
    // Record overrides
    override class func databaseTableName() -> String { return "authors" }
    required init(_ row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        super.init(row)
    }
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}

extension Author : CustomStringConvertible {
    var description: String {
        return name
    }
}

class Book : Record {
    var id: Int64?
    var authorId: Int64?
    var title: String
    
    init(authorId: Int64?, title: String) {
        self.authorId = authorId
        self.title = title
        super.init()
    }
    
    // Author relation
    static let author = Relation(to: "authors", fromColumns: ["authorId"])
    var author: Author?
    
    // Record overrides
    override class func databaseTableName() -> String { return "books" }
    required init(_ row: Row) {
        id = row.value(named: "id")
        authorId = row.value(named: "authorId")
        title = row.value(named: "title")
        
        if let authorRow = row.scoped(on: Book.author) {
            author = Author(authorRow)
        }
        
        super.init(row)
    }
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "authorId": authorId, "title": title]
    }
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}

class Person : TableMapping {
    static func databaseTableName() -> String { return "persons" }
}

extension Book : CustomStringConvertible {
    var description: String {
        return title
    }
}

// Populate database

let coetzee = Author(name: "J. M. Coetzee")
let melville = Author(name: "Herman Melville")
let munro = Author(name: "Alice Munro")
let robinson = Author(name: "Kim Stanley Robinson")
let sacks = Author(name: "Oliver Sacks")

try! dbQueue.inDatabase { db in
    try coetzee.insert(db)
    try melville.insert(db)
    try munro.insert(db)
    try robinson.insert(db)
    try sacks.insert(db)
    
    try Book(authorId: coetzee.id, title: "Disgrace").insert(db)
    try Book(authorId: coetzee.id, title: "Foe").insert(db)
    try Book(authorId: melville.id, title: "Moby Dick").insert(db)
    try Book(authorId: munro.id, title: "Runaway").insert(db)
    try Book(authorId: robinson.id, title: "Red Mars").insert(db)
    try Book(authorId: robinson.id, title: "Green Mars").insert(db)
    try Book(authorId: robinson.id, title: "Blue Mars").insert(db)
    try Book(authorId: sacks.id, title: "The Man Who Mistook His Wife for a Hat").insert(db)
    try Book(authorId: sacks.id, title: "Musicophilia: Tales of Music and the Brain").insert(db)
}

dbQueue.inDatabase { db in
    for book in Book.include(Book.author).fetchAll(db) {
        print("\(book) by \(book.author!)")
    }
    
    let father = Relation(to: "persons", fromColumns: ["fatherId"])
    let mother = Relation(to: "persons", fromColumns: ["motherId"])
    let request = Person.join(
        father.join(father, mother),
        mother.join(father, mother))
    let (st, a) = try! request.prepare(db)
    print(st.sql)
    for row in Row.fetch(db, request) {
    }
}
