import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

class ValueObservationMapTests: GRDBTestCase {
    func testMap() throws {
        let valueObservation = ValueObservation
            .tracking(DatabaseRegion.fullDatabase, fetch: {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            })
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
        var observation = ValueObservation.tracking(DatabaseRegion(), fetch: { _ in })
        observation.requiresWriteAccess = true
        observation.scheduling = .unsafe
        
        let mappedObservation = observation.map { _ in }
        XCTAssertEqual(mappedObservation.requiresWriteAccess, observation.requiresWriteAccess)
        switch mappedObservation.scheduling {
        case .unsafe:
            break
        default:
            XCTFail()
        }
    }
}
