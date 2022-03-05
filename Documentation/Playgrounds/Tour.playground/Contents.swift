//: To run this playground:
//:
//: - Open GRDB.xcworkspace
//: - Select the GRDBOSX scheme: menu Product > Scheme > GRDBOSX
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
            favorite BOOLEAN NOT NULL,
            latitude DOUBLE NOT NULL,
            longitude DOUBLE NOT NULL
        )
        """)
    
    try db.execute(sql: """
        INSERT INTO place (title, favorite, latitude, longitude)
        VALUES (?, ?, ?, ?)
        """, arguments: ["Paris", true, 48.85341, 2.3488])
    let parisId = db.lastInsertedRowID
}


//: Fetch database rows and values

try! dbQueue.inDatabase { db in
    let rows = try Row.fetchCursor(db, sql: "SELECT * FROM place")
    while let row = try rows.next() {
        let title: String = try row["title"]
        let favorite: Bool = try row["favorite"]
        let coordinate = try CLLocationCoordinate2D(
            latitude: row["latitude"],
            longitude: row["longitude"])
        print("Fetched", title, favorite, coordinate)
    }
    
    let placeCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM place")! // Int
    let placeTitles = try String.fetchAll(db, sql: "SELECT title FROM place") // [String]
}


//: Insert and fetch records

struct Place {
    var id: Int64?
    var title: String?
    var favorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// Adopt FetchableRecord
extension Place : FetchableRecord {
    init(row: Row) throws {
        id = try row["id"]
        title = try row["title"]
        favorite = try row["favorite"]
        coordinate = CLLocationCoordinate2DMake(
            try row["latitude"],
            try row["longitude"])
    }
}

// Adopt TableRecord
extension Place : TableRecord {
    static let databaseTableName = "place"
}

// Adopt MutablePersistableRecord
extension Place : MutablePersistableRecord {
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["title"] = title
        container["favorite"] = favorite
        container["latitude"] = coordinate.latitude
        container["longitude"] = coordinate.longitude
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

try dbQueue.inDatabase { db in
    var berlin = Place(
        id: nil,
        title: "Berlin",
        favorite: false,
        coordinate: CLLocationCoordinate2DMake(52.52437, 13.41053))
    
    try berlin.insert(db)
    berlin.id // some value
    
    berlin.favorite = true
    try berlin.update(db)
    
    // Fetch from SQL
    let places = try Place.fetchAll(db, sql: "SELECT * FROM place") // [Place]
    
    
    //: Avoid SQL with the query interface:
    
    let title = Column("title")
    let favorite = Column("favorite")
    
    berlin = try Place.filter(title == "Berlin").fetchOne(db)!   // Place
    let paris = try Place.fetchOne(db, key: 1)                   // Place?
    let favoritePlaces = try Place                               // [Place]
        .filter(favorite == true)
        .order(title)
        .fetchAll(db)
}
