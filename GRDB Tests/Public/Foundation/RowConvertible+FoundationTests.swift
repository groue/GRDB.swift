import XCTest
import GRDB

struct PointOfInterest : RowConvertible {
    let latitude: Double
    let longitude: Double
    let title: String?
    
    init(row: Row) {
        latitude = row.value(named: "latitude")
        longitude = row.value(named: "longitude")
        title = row.value(named: "title")
    }
}

class RowConvertibleFoundationTests: GRDBTestCase {
    
    func testInvalidNSDictionaryInitializer() {
        let dictionary: NSDictionary = ["a": NSObject()]
        let s = PointOfInterest(dictionary: dictionary)
        XCTAssertTrue(s == nil)
    }
    
    func testNSDictionaryInitializer() {
        let latitude = 41.8919300
        let longitude = 12.5113300
        let dictionary: NSDictionary = ["latitude": latitude, "longitude": longitude, "title": NSNull()]
        let s = PointOfInterest(dictionary: dictionary)!
        XCTAssertEqual(s.latitude, latitude)
        XCTAssertEqual(s.longitude, longitude)
        XCTAssertTrue(s.title == nil)
    }

}
