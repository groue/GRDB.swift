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

dbQueue.inDatabase { db in
    for row in Row.fetchAll(db, "SELECT * FROM pointOfInterests") {
        let title: String = row.value(named: "title")
        let favorite: Bool = row.value(named: "favorite")
        let coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
        print("Fetched", title, favorite, coordinate)
    }
    
    let poiCount = Int.fetchOne(db, "SELECT COUNT(*) FROM pointOfInterests")! // Int
    let poiTitles = String.fetchAll(db, "SELECT title FROM pointOfInterests") // [String]
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
        id = row.value(named: "id")
        title = row.value(named: "title")
        favorite = row.value(named: "favorite")
        coordinate = CLLocationCoordinate2DMake(
            row.value(named: "latitude"),
            row.value(named: "longitude"))
    }
}

// Adopt TableMapping
extension PointOfInterest : TableMapping {
    static let databaseTableName = "pointOfInterests"
}

// Adopt MutablePersistable
extension PointOfInterest : MutablePersistable {
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "title": title,
            "favorite": favorite,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]
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
    let pois = PointOfInterest.fetchAll(db, "SELECT * FROM pointOfInterests") // [PointOfInterest]
    
    
    //: Avoid SQL with the query interface:
    
    let title = Column("title")
    let favorite = Column("favorite")
    
    berlin = PointOfInterest.filter(title == "Berlin").fetchOne(db)!   // PointOfInterest
    let paris = PointOfInterest.fetchOne(db, key: 1)                   // PointOfInterest?
    let favoritePois = PointOfInterest                                 // [PointOfInterest]
        .filter(favorite)
        .order(title)
        .fetchAll(db)
}
