import XCTest

class GRDBCrashTestCase: GRDBTestCase {
    
    // This method does not actually catch any crash.
    // But it expresses an intent :-)
    func assertCrash(message: String, @noescape block: () throws -> ()) {
        do {
            try block()
            XCTFail("Crash expected: \(message)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
