import XCTest
import GRDB

class ValueObservationMapTests: GRDBTestCase {
    func testMap() throws {
        let valueObservation = ValueObservation
            .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
            .map { "\($0)" }
        
        try assertValueObservation(
            valueObservation,
            records: ["0", "1", "2"],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
    }
    
    func testMapPreservesConfiguration() {
        var observation = ValueObservation.trackingConstantRegion { _ in }
        observation.requiresWriteAccess = true
        
        let mappedObservation = observation.map { _ in }
        XCTAssertEqual(mappedObservation.requiresWriteAccess, observation.requiresWriteAccess)
    }
}
