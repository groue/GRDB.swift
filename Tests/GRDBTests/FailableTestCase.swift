// Inspired by https://github.com/groue/CombineExpectations
import XCTest

/// A XCTestCase subclass that can test its own failures.
class FailureTestCase: XCTestCase {
    private struct Failure: Hashable {
        var prefix: String
        var file: String
        var line: Int
        var expected: Bool
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(0)
        }
        
        static func == (lhs: Failure, rhs: Failure) -> Bool {
            lhs.prefix.hasPrefix(rhs.prefix) || rhs.prefix.hasPrefix(lhs.prefix)
        }
    }
    
    private var recordedFailures: [Failure] = []
    private var isRecordingFailures = false
    
    func assertFailure(_ prefixes: String..., file: StaticString = #file, line: UInt = #line, _ execute: () throws -> Void) rethrows {
        let recordedFailures = try recordingFailures(execute)
        if prefixes.isEmpty {
            if recordedFailures.isEmpty {
                recordFailure(
                    withDescription: "No failure did happen",
                    inFile: file.description,
                    atLine: Int(line),
                    expected: true)
            }
        } else {
            let expectedFailures = prefixes.map { Failure(prefix: $0, file: file.description, line: Int(line), expected: true) }
            assertMatch(
                recordedFailures: recordedFailures,
                expectedFailures: expectedFailures)
        }
    }
    
    override func setUp() {
        super.setUp()
        isRecordingFailures = false
        recordedFailures = []
    }
    
    override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
        if isRecordingFailures {
            recordedFailures.append(Failure(prefix: description, file: filePath, line: lineNumber, expected: expected))
        } else {
            super.recordFailure(withDescription: description, inFile: filePath, atLine: lineNumber, expected: expected)
        }
    }
    
    private func recordingFailures(_ execute: () throws -> Void) rethrows -> [Failure] {
        let oldRecordingFailures = isRecordingFailures
        let oldRecordedFailures = recordedFailures
        defer {
            isRecordingFailures = oldRecordingFailures
            recordedFailures = oldRecordedFailures
        }
        isRecordingFailures = true
        recordedFailures = []
        try execute()
        let result = recordedFailures
        return result
    }
    
    private func assertMatch(recordedFailures: [Failure], expectedFailures: [Failure]) {
        var recordedFailures = recordedFailures
        var expectedFailures = expectedFailures
        
        while !recordedFailures.isEmpty {
            let failure = recordedFailures.removeFirst()
            if let index = expectedFailures.firstIndex(of: failure) {
                expectedFailures.remove(at: index)
            } else {
                recordFailure(
                    withDescription: failure.prefix,
                    inFile: failure.file,
                    atLine: failure.line,
                    expected: failure.expected)
            }
        }
        
        while !expectedFailures.isEmpty {
            let failure = expectedFailures.removeFirst()
            if let index = recordedFailures.firstIndex(of: failure) {
                recordedFailures.remove(at: index)
            } else {
                recordFailure(
                    withDescription: "Failure did not happen: \(failure.prefix)",
                    inFile: failure.file,
                    atLine: failure.line,
                    expected: failure.expected)
            }
        }
    }
    
    // MARK: - Tests
    
    func testEmptyTest() {
    }
    
    func testExpectedAnyFailure() {
        assertFailure {
            XCTFail("foo")
        }
        assertFailure {
            XCTFail("foo")
            XCTFail("bar")
        }
    }
    
    func testMissingAnyFailure() {
        assertFailure("No failure did happen") {
            assertFailure {
            }
        }
    }
    
    func testExpectedFailure() {
        assertFailure("failed - foo") {
            XCTFail("foo")
        }
    }
    
    func testExpectedFailureMatchesOnPrefix() {
        assertFailure("failed - foo") {
            XCTFail("foobarbaz")
        }
    }
    
    func testOrderOfExpectedFailureIsIgnored() {
        assertFailure("failed - foo", "failed - bar") {
            XCTFail("foo")
            XCTFail("bar")
        }
        assertFailure("failed - bar", "failed - foo") {
            XCTFail("foo")
            XCTFail("bar")
        }
    }
    
    func testExpectedFailureCanBeRepeated() {
        assertFailure("failed - foo", "failed - foo", "failed - bar") {
            XCTFail("foo")
            XCTFail("bar")
            XCTFail("foo")
        }
    }
    
    func testExactNumberOfRepetitionIsRequired() {
        assertFailure("Failure did not happen: failed - foo") {
            assertFailure("failed - foo", "failed - foo") {
                XCTFail("foo")
            }
        }
        assertFailure("failed - foo") {
            assertFailure("failed - foo", "failed - foo") {
                XCTFail("foo")
                XCTFail("foo")
                XCTFail("foo")
            }
        }
    }
    
    func testUnexpectedFailure() {
        assertFailure("Failure did not happen: failed - foo") {
            assertFailure("failed - foo") {
            }
        }
    }
    
    func testMissedFailure() {
        assertFailure("failed - bar") {
            assertFailure("failed - foo") {
                XCTFail("foo")
                XCTFail("bar")
            }
        }
    }
}
