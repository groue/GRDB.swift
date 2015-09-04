import XCTest
import GRDB

struct CLLocationCoordinate2D {
    let latitude: Double
    let longitude: Double
}

class Placemark : RowModel {
    var id: Int64?
    var name: String?
    var coordinate: CLLocationCoordinate2D?
    
    override init() {
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    init(name: String?, coordinate: CLLocationCoordinate2D?) {
        self.name = name
        self.coordinate = coordinate
        super.init()
    }
    
    override class var databaseTable: Table? {
        return Table(named: "placemarks", primaryKey: .RowID("id"))
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "latitude": coordinate?.latitude,
            "longitude": coordinate?.longitude]
    }
    
    override func updateFromRow(row: Row) {
        // Let's keep things simple, and only update self.coordinate if the
        // row contains both lat and long columns.
        //
        // We test column presence by extracting DatabaseValues, which may
        // contain coordinates, or NULL:
        if let latitude = row["latitude"], let longitude = row["longitude"] {
            // Both columns are present.
            switch (latitude.value() as Double?, longitude.value() as Double?) {
            case (let latitude?, let longitude?):
                // Both latitude and longitude are not nil.
                coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            default:
                coordinate = nil
            }
        }
        
        // Update other columns
        super.updateFromRow(row)
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "id": id = dbv.value()
        case "name": name = dbv.value()
        default: super.setDatabaseValue(dbv, forColumn: column)
        }
    }
}

class RowModelUpdateFromRowTests: RowModelTestCase {
    
    func testInitFromRow() {
        let parisLatitude = 48.8534100
        let parisLongitude = 2.3488000
        let row = Row(dictionary: ["name": "Paris", "latitude": parisLatitude, "longitude": parisLongitude])
        let paris = Placemark(row: row)
        XCTAssertEqual(paris.name!, "Paris")
        XCTAssertEqual(paris.coordinate!.latitude, parisLatitude)
        XCTAssertEqual(paris.coordinate!.longitude, parisLongitude)
    }
    
    func testUpdateFromRow() {
        let parisLatitude = 48.8534100
        let parisLongitude = 2.3488000
        let paris = Placemark()
        
        // Update name and coordinate
        paris.updateFromRow(Row(dictionary: ["name": "Paris", "latitude": parisLatitude, "longitude": parisLongitude]))
        XCTAssertEqual(paris.name!, "Paris")
        XCTAssertEqual(paris.coordinate!.latitude, parisLatitude)
        XCTAssertEqual(paris.coordinate!.longitude, parisLongitude)

        // Missing coordinate prevents coordinate update
        paris.updateFromRow(Row(dictionary: ["longitude": 0]))
        XCTAssertEqual(paris.coordinate!.latitude, parisLatitude)
        XCTAssertEqual(paris.coordinate!.longitude, parisLongitude)
        
        // Missing coordinate prevents coordinate update
        paris.updateFromRow(Row(dictionary: ["latitude": 0]))
        XCTAssertEqual(paris.coordinate!.latitude, parisLatitude)
        XCTAssertEqual(paris.coordinate!.longitude, parisLongitude)
        
        // One nil coordinate resets coordinate.
        paris.updateFromRow(Row(dictionary: ["latitude": nil, "longitude": 0]))
        XCTAssertTrue(paris.coordinate == nil)
    }
    
    func testUpdateFromRowForFetchedModels() {
        let parisLatitude = 48.8534100
        let parisLongitude = 2.3488000
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE placemarks (id INTEGER PRIMARY KEY, name TEXT, latitude REAL, longitude REAL)")
                try db.execute("INSERT INTO placemarks (name, latitude, longitude) VALUES (?,?,?)", arguments: ["Paris", parisLatitude, parisLongitude])
                let paris = Placemark.fetchOne(db, "SELECT * FROM placemarks")!
                XCTAssertEqual(paris.name!, "Paris")
                XCTAssertEqual(paris.coordinate!.latitude, parisLatitude)
                XCTAssertEqual(paris.coordinate!.longitude, parisLongitude)
            }
        }
    }
    
    func testUpdateFromRowForReload() {
        let parisLatitude = 48.8534100
        let parisLongitude = 2.3488000
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE placemarks (id INTEGER PRIMARY KEY, name TEXT, latitude REAL, longitude REAL)")
                try db.execute("INSERT INTO placemarks (name, latitude, longitude) VALUES (?,?,?)", arguments: ["Paris", parisLatitude, parisLongitude])
                let paris = Placemark.fetchOne(db, "SELECT * FROM placemarks")!
                paris.coordinate = nil
                try paris.reload(db)
                XCTAssertEqual(paris.name!, "Paris")
                XCTAssertEqual(paris.coordinate!.latitude, parisLatitude)
                XCTAssertEqual(paris.coordinate!.longitude, parisLongitude)
            }
        }
    }
    
    func testUpdateFromRowForCopiedModels() {
        let parisLatitude = 48.8534100
        let parisLongitude = 2.3488000
        let paris1 = Placemark(name: "Paris", coordinate: CLLocationCoordinate2D(latitude: parisLatitude, longitude: parisLongitude))
        let paris2 = Placemark()
        paris2.copyDatabaseValuesFrom(paris1)
        XCTAssertEqual(paris2.name!, "Paris")
        XCTAssertEqual(paris2.coordinate!.latitude, parisLatitude)
        XCTAssertEqual(paris2.coordinate!.longitude, parisLongitude)
    }
}
