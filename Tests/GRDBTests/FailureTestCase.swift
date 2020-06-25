// Inspired by https://github.com/groue/CombineExpectations
import XCTest

/// A XCTestCase subclass that can test its own failures.
class FailureTestCase: XCTestCase {
    private struct Failure: Hashable {
        #if compiler(>=5.3)
        let issue: XCTIssue
        #else
        var description: String
        var file: String
        var line: Int
        var expected: Bool
        #endif
        
        #if compiler(>=5.3)
        func issue(prefix: String = "") -> XCTIssue {
            if prefix.isEmpty {
                return issue
            } else {
                return XCTIssue(
                    type: issue.type,
                    compactDescription: "\(prefix): \(issue.compactDescription)",
                    detailedDescription: issue.detailedDescription,
                    sourceCodeContext: issue.sourceCodeContext,
                    associatedError: issue.associatedError,
                    attachments: issue.attachments)
            }
        }
        #else
        func failure(prefix: String = "") -> (description: String, file: String, line: Int, expected: Bool) {
            let prefix = prefix.isEmpty ? "" : "\(prefix): "
            return (
                description: prefix + description,
                file: file,
                line: line,
                expected: expected)
        }
        #endif
        
        #if compiler(>=5.3)
        private var description: String {
            return issue.compactDescription
        }
        #endif
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(0)
        }
        
        static func == (lhs: Failure, rhs: Failure) -> Bool {
            lhs.description.hasPrefix(rhs.description) || rhs.description.hasPrefix(lhs.description)
        }
    }
    
    private var recordedFailures: [Failure] = []
    private var isRecordingFailures = false
    
    func assertFailure(_ prefixes: String..., file: StaticString = #file, line: UInt = #line, _ execute: () throws -> Void) rethrows {
        let recordedFailures = try recordingFailures(execute)
        if prefixes.isEmpty {
            if recordedFailures.isEmpty {
                #if compiler(>=5.3)
                record(XCTIssue(
                        type: .assertionFailure,
                        compactDescription: "No failure did happen",
                        detailedDescription: nil,
                        sourceCodeContext: XCTSourceCodeContext(
                            location: XCTSourceCodeLocation(
                                filePath: String(describing: file),
                                lineNumber: Int(line))),
                        associatedError: nil,
                        attachments: []))
                #else
                recordFailure(
                    withDescription: "No failure did happen",
                    inFile: file.description,
                    atLine: Int(line),
                    expected: true)
                #endif
            }
        } else {
            let expectedFailures = prefixes.map { prefix -> Failure in
                #if compiler(>=5.3)
                return Failure(issue: XCTIssue(
                                type: .assertionFailure,
                                compactDescription: prefix,
                                detailedDescription: nil,
                                sourceCodeContext: XCTSourceCodeContext(
                                    location: XCTSourceCodeLocation(
                                        filePath: String(describing: file),
                                        lineNumber: Int(line))),
                                associatedError: nil,
                                attachments: []))
                #else
                return Failure(
                    description: prefix,
                    file: String(describing: file),
                    line: Int(line),
                    expected: true)
                #endif
            }
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
    
    #if compiler(>=5.3)
    override func record(_ issue: XCTIssue) {
        if isRecordingFailures {
            recordedFailures.append(Failure(issue: issue))
        } else {
            super.record(issue)
        }
    }
    #else
    override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
        if isRecordingFailures {
            recordedFailures.append(Failure(
                                        description: description,
                                        file: filePath,
                                        line: lineNumber,
                                        expected: expected))
        } else {
            super.recordFailure(
                withDescription: description,
                inFile: filePath,
                atLine: lineNumber,
                expected: expected)
        }
    }
    #endif
    
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
                #if compiler(>=5.3)
                record(failure.issue())
                #else
                let failure = failure.failure()
                recordFailure(
                    withDescription: failure.description,
                    inFile: failure.file,
                    atLine: failure.line,
                    expected: failure.expected)
                #endif
            }
        }
        
        while !expectedFailures.isEmpty {
            let failure = expectedFailures.removeFirst()
            if let index = recordedFailures.firstIndex(of: failure) {
                recordedFailures.remove(at: index)
            } else {
                #if compiler(>=5.3)
                record(failure.issue(prefix: "Failure did not happen"))
                #else
                let failure = failure.failure(prefix: "Failure did not happen")
                recordFailure(
                    withDescription: failure.description,
                    inFile: failure.file,
                    atLine: failure.line,
                    expected: failure.expected)
                #endif
            }
        }
    }
}

// MARK: - Tests

class FailureTestCaseTests: FailureTestCase {
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
