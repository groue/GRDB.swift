//: To run this playground:
//:
//: - Open GRDB.xcworkspace
//: - Select the GRDB scheme: menu Product > Scheme > GRDB
//: - Build: menu Product > Build
//: - Select the playground in the Playgrounds Group
//: - Run the playground
//:
//: Tour
//: ======
//:
//: This playground is a quick tour of GRDB.

import GRDB
import CoreLocation


//: Open a connection to the database

// Open an in-memory database that logs all SQL statements
var configuration = Configuration()
configuration.prepareDatabase { db in
    db.trace { print("SQL> \($0)") }
}
let dbQueue = try DatabaseQueue(configuration: configuration)


//: Execute SQL queries

try dbQueue.inDatabase { db in
    try db.execute(sql: """
        CREATE TABLE place (
            id INTEGER PRIMARY KEY,
            title TEXT,
            isFavorite BOOLEAN NOT NULL,
            latitude DOUBLE NOT NULL,
            longitude DOUBLE NOT NULL
        )
        """)
    
    try db.execute(sql: """
        INSERT INTO place (title, isFavorite, latitude, longitude)
        VALUES (?, ?, ?, ?)
        """, arguments: ["Paris", true, 48.85341, 2.3488])
    let parisId = db.lastInsertedRowID
}


//: Fetch database rows and values

try! dbQueue.inDatabase { db in
    let rows = try Row.fetchCursor(db, sql: "SELECT * FROM place")
    while let row = try rows.next() {
        let title: String = row["title"]
        let isFavorite: Bool = row["isFavorite"]
        let coordinate = CLLocationCoordinate2D(
            latitude: row["latitude"],
            longitude: row["longitude"])
        print("Fetched", title, isFavorite, coordinate)
    }
    
    let placeCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM place")! // Int
    let placeTitles = try String.fetchAll(db, sql: "SELECT title FROM place") // [String]
}


//: Insert and fetch records

struct Place {
    var id: Int64?
    var title: String?
    var isFavorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// Adopt FetchableRecord
extension Place : FetchableRecord {
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        isFavorite = row[Columns.isFavorite]
        coordinate = CLLocationCoordinate2DMake(
            row[Columns.latitude],
            row[Columns.longitude])
    }
}

// Adopt TableRecord
extension Place : TableRecord {
    static let databaseTableName = "place"
    
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let isFavorite = Column("isFavorite")
        static let latitude = Column("latitude")
        static let longitude = Column("longitude")
    }
}

// Adopt MutablePersistableRecord
extension Place : MutablePersistableRecord {
    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.isFavorite] = isFavorite
        container[Columns.latitude] = coordinate.latitude
        container[Columns.longitude] = coordinate.longitude
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

try dbQueue.inDatabase { db in
    var berlin = Place(
        id: nil,
        title: "Berlin",
        isFavorite: false,
        coordinate: CLLocationCoordinate2DMake(52.52437, 13.41053))
    
    try berlin.insert(db)
    berlin.id // some value
    
    berlin.isFavorite = true
    try berlin.update(db)
    
    // Fetch from SQL
    let places = try Place.fetchAll(db, sql: "SELECT * FROM place") // [Place]
    
    
    //: Avoid SQL with the query interface:
    
    berlin = try Place.filter { $0.title == "Berlin" }.fetchOne(db)! // Place
    let paris = try Place.fetchOne(db, key: 1)                   // Place?
    let favoritePlaces = try Place                               // [Place]
        .filter { $0.isFavorite == true }
        .order { $0.title }
        .fetchAll(db)
}
