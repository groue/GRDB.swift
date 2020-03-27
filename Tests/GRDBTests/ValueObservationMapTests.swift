import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    @testable import GRDB
#endif

class ValueObservationMapTests: GRDBTestCase {
    func testMap() throws {
        let valueObservation = ValueObservation
            .tracking {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            }
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
        let queue = DispatchQueue(label: "test")
        var observation = ValueObservation
            .tracking { _ in }
            .notify(onDispatchQueue: queue)
        observation.requiresWriteAccess = true
        
        let mappedObservation = observation.map { _ in }
        XCTAssertEqual(mappedObservation.requiresWriteAccess, observation.requiresWriteAccess)
        switch mappedObservation._scheduling {
        case let .async(onDispatchQueue: q):
            XCTAssert(q === queue)
        default:
            XCTFail()
        }
    }
}
