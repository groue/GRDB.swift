import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

class ValueObservationFetchTests: GRDBTestCase {
}

// let observation = ValueObservation.observing(<#T##regions: DatabaseRegionConvertible...##DatabaseRegionConvertible#>, fetch: <#T##(Database) throws -> Value#>)
// let observation = ValueObservation.observing(withUniquing: <#T##DatabaseRegionConvertible...##DatabaseRegionConvertible#>, fetch: <#T##(Database) throws -> Equatable#>)
