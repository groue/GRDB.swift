import XCTest
import GRDB

typealias CLLocationDegrees = Double
struct CLLocationCoordinate2D {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
}

class Placemark : Record {
    var id: Int64?
    var name: String?
    var coordinate: CLLocationCoordinate2D?
    
    init(id: Int64? = nil, name: String?, coordinate: CLLocationCoordinate2D?) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        super.init()
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE placemarks (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT, " +
                "latitude REAL, " +
                "longitude REAL" +
            ")")
    }
    
    // Record
    
    override class func databaseTableName() -> String {
        return "placemarks"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "latitude": coordinate?.latitude,
            "longitude": coordinate?.longitude]
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        
        if let latitude: CLLocationDegrees = row.value(named: "latitude"), let longitude: CLLocationDegrees = row.value(named: "longitude") {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            coordinate = nil
        }
        
        super.init(row: row)
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.id = rowID
    }
}

class RecordUpdateFromRowTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPlacemark", Placemark.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testInitFromRow() {
        let parisLatitude = 48.8534100
        let parisLongitude = 2.3488000
        let row = Row(dictionary: ["name": "Paris", "latitude": parisLatitude, "longitude": parisLongitude])
        let paris = Placemark(row: row)
        XCTAssertEqual(paris.name!, "Paris")
        XCTAssertEqual(paris.coordinate!.latitude, parisLatitude)
        XCTAssertEqual(paris.coordinate!.longitude, parisLongitude)
    }
    
    func testUpdateFromRowForFetchedRecords() {
        let parisLatitude = 48.8534100
        let parisLongitude = 2.3488000
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO placemarks (name, latitude, longitude) VALUES (?,?,?)", arguments: ["Paris", parisLatitude, parisLongitude])
                let paris = Placemark.fetchOne(db, "SELECT * FROM placemarks")!
                XCTAssertEqual(paris.name!, "Paris")
                XCTAssertEqual(paris.coordinate!.latitude, parisLatitude)
                XCTAssertEqual(paris.coordinate!.longitude, parisLongitude)
            }
        }
    }
    
    func testCopy() {
        let parisLatitude = 48.8534100
        let parisLongitude = 2.3488000
        let paris1 = Placemark(name: "Paris", coordinate: CLLocationCoordinate2D(latitude: parisLatitude, longitude: parisLongitude))
        let paris2 = paris1.copy()
        XCTAssertEqual(paris2.name!, "Paris")
        XCTAssertEqual(paris2.coordinate!.latitude, parisLatitude)
        XCTAssertEqual(paris2.coordinate!.longitude, parisLongitude)
    }
}
