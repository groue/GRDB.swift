import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class DatabaseReaderTests : GRDBTestCase {
    // TODO
}
