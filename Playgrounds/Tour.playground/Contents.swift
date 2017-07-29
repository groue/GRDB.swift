//: To run this playground, select and build the GRDBOSX scheme.
//:
//: Tour
//: ======
//:
//: This playground is a tour of GRDB.

import GRDB
import CoreLocation


//: Open a connection to the database

// Open an in-memory database that logs all SQL statements
var configuration = Configuration()
configuration.trace = { print($0) }
let dbQueue = DatabaseQueue(configuration: configuration)


//: Execute SQL queries

try dbQueue.inDatabase { db in
    try db.execute(
        "CREATE TABLE pointOfInterests (" +
            "id INTEGER PRIMARY KEY, " +
            "title TEXT, " +
            "favorite BOOLEAN NOT NULL, " +
            "latitude DOUBLE NOT NULL, " +
            "longitude DOUBLE NOT NULL" +
        ")")
    
    try db.execute(
        "INSERT INTO pointOfInterests (title, favorite, latitude, longitude) " +
        "VALUES (?, ?, ?, ?)",
        arguments: ["Paris", true, 48.85341, 2.3488])
    let parisId = db.lastInsertedRowID
}


//: Fetch database rows and values

try dbQueue.inDatabase { db in
    let rows = try Row.fetchCursor(db, "SELECT * FROM pointOfInterests")
    while let row = try rows.next() {
        let title: String = row["title"]
        let favorite: Bool = row["favorite"]
        let coordinate = CLLocationCoordinate2DMake(
            row["latitude"],
            row["longitude"])
        print("Fetched", title, favorite, coordinate)
    }
    
    let poiCount = try Int.fetchOne(db, "SELECT COUNT(*) FROM pointOfInterests")! // Int
    let poiTitles = try String.fetchAll(db, "SELECT title FROM pointOfInterests") // [String]
}


//: Insert and fetch records

struct PointOfInterest {
    var id: Int64?
    var title: String?
    var favorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// Adopt RowConvertible
extension PointOfInterest : RowConvertible {
    init(row: Row) {
        id = row["id"]
        title = row["title"]
        favorite = row["favorite"]
        coordinate = CLLocationCoordinate2DMake(
            row["latitude"],
            row["longitude"])
    }
}

// Adopt TableMapping
extension PointOfInterest : TableMapping {
    static let databaseTableName = "pointOfInterests"
}

// Adopt MutablePersistable
extension PointOfInterest : MutablePersistable {
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
    var berlin = PointOfInterest(
        id: nil,
        title: "Berlin",
        favorite: false,
        coordinate: CLLocationCoordinate2DMake(52.52437, 13.41053))
    
    try berlin.insert(db)
    berlin.id // some value
    
    berlin.favorite = true
    try berlin.update(db)
    
    // Fetch from SQL
    let pois = try PointOfInterest.fetchAll(db, "SELECT * FROM pointOfInterests") // [PointOfInterest]
    
    
    //: Avoid SQL with the query interface:
    
    let title = Column("title")
    let favorite = Column("favorite")
    
    berlin = try PointOfInterest.filter(title == "Berlin").fetchOne(db)!   // PointOfInterest
    let paris = try PointOfInterest.fetchOne(db, key: 1)                   // PointOfInterest?
    let favoritePois = try PointOfInterest                                 // [PointOfInterest]
        .filter(favorite)
        .order(title)
        .fetchAll(db)
}
