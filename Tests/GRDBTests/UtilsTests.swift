import XCTest

@testable import GRDB

class UtilsTests: XCTestCase {

    func testThrowingFirstError() {
        struct ExecuteError: Error { }
        struct FinallyError: Error { }
        var actions: [String]
        
        do {
            actions = []
            let result = try throwingFirstError(
                execute: { () -> String in
                    actions.append("execute")
                    return "foo"
            },
                finally: {
                    actions.append("finally")
            })
            XCTAssertEqual(result, "foo")
            XCTAssertEqual(actions, ["execute", "finally"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        do {
            actions = []
            _ = try throwingFirstError(
                execute: { () -> String in
                    actions.append("execute")
                    throw ExecuteError()
            },
                finally: {
                    actions.append("finally")
            })
            XCTFail("Expected error")
        } catch is ExecuteError {
            XCTAssertEqual(actions, ["execute", "finally"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        do {
            actions = []
            _ = try throwingFirstError(
                execute: { () -> String in
                    actions.append("execute")
                    return "foo"
            },
                finally: {
                    actions.append("finally")
                    throw FinallyError()
            })
            XCTFail("Expected error")
        } catch is FinallyError {
            XCTAssertEqual(actions, ["execute", "finally"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        do {
            actions = []
            _ = try throwingFirstError(
                execute: { () -> String in
                    actions.append("execute")
                    throw ExecuteError()
            },
                finally: {
                    actions.append("finally")
                    throw FinallyError()
            })
            XCTFail("Expected error")
        } catch is ExecuteError {
            XCTAssertEqual(actions, ["execute", "finally"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
