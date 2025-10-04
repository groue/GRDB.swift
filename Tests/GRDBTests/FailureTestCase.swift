// Inspired by https://github.com/groue/CombineExpectations
import XCTest

/// A XCTestCase subclass that can test its own failures.
class FailureTestCase: XCTestCase {
    private struct Failure: Hashable {
        #if canImport(Darwin)
        let issue: XCTIssue

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

        private var description: String {
            return issue.compactDescription
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(0)
        }
        
        static func == (lhs: Failure, rhs: Failure) -> Bool {
            lhs.description.hasPrefix(rhs.description) || rhs.description.hasPrefix(lhs.description)
        }
        #endif
    }
    
    private var recordedFailures: [Failure] = []
    private var isRecordingFailures = false
    
    func assertFailure(_ prefixes: String..., file: StaticString = #file, line: UInt = #line, _ execute: () throws -> Void) throws {
        #if !canImport(Darwin)
        throw XCTSkip("XCTIssue unavailable on non-Darwin platforms")
        #else
        let recordedFailures = try recordingFailures(execute)
        if prefixes.isEmpty {
            if recordedFailures.isEmpty {
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
            }
        } else {
            let expectedFailures = prefixes.map { prefix -> Failure in
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
            }
            assertMatch(
                recordedFailures: recordedFailures,
                expectedFailures: expectedFailures)
        }
        #endif
    }
    
    override func setUp() {
        super.setUp()
        isRecordingFailures = false
        recordedFailures = []
    }

    #if canImport(Darwin)
    override func record(_ issue: XCTIssue) {
        if isRecordingFailures {
            recordedFailures.append(Failure(issue: issue))
        } else {
            super.record(issue)
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
                record(failure.issue())
            }
        }
        
        while !expectedFailures.isEmpty {
            let failure = expectedFailures.removeFirst()
            if let index = recordedFailures.firstIndex(of: failure) {
                recordedFailures.remove(at: index)
            } else {
                record(failure.issue(prefix: "Failure did not happen"))
            }
        }
    }
    #endif
}

// MARK: - Tests

class FailureTestCaseTests: FailureTestCase {
    func testEmptyTest() {
    }
    
    func testExpectedAnyFailure() throws {
        try assertFailure {
            XCTFail("foo")
        }
        try assertFailure {
            XCTFail("foo")
            XCTFail("bar")
        }
    }
    
    func testMissingAnyFailure() throws {
        try assertFailure("No failure did happen") {
            try assertFailure {
            }
        }
    }
    
    func testExpectedFailure() throws {
        try assertFailure("failed - foo") {
            XCTFail("foo")
        }
    }
    
    func testExpectedFailureMatchesOnPrefix() throws {
        try assertFailure("failed - foo") {
            XCTFail("foobarbaz")
        }
    }
    
    func testOrderOfExpectedFailureIsIgnored() throws {
        try assertFailure("failed - foo", "failed - bar") {
            XCTFail("foo")
            XCTFail("bar")
        }
        try assertFailure("failed - bar", "failed - foo") {
            XCTFail("foo")
            XCTFail("bar")
        }
    }
    
    func testExpectedFailureCanBeRepeated() throws {
        try assertFailure("failed - foo", "failed - foo", "failed - bar") {
            XCTFail("foo")
            XCTFail("bar")
            XCTFail("foo")
        }
    }
    
    func testExactNumberOfRepetitionIsRequired() throws {
        try assertFailure("Failure did not happen: failed - foo") {
            try assertFailure("failed - foo", "failed - foo") {
                XCTFail("foo")
            }
        }
        try assertFailure("failed - foo") {
            try assertFailure("failed - foo", "failed - foo") {
                XCTFail("foo")
                XCTFail("foo")
                XCTFail("foo")
            }
        }
    }
    
    func testUnexpectedFailure() throws {
        try assertFailure("Failure did not happen: failed - foo") {
            try assertFailure("failed - foo") {
            }
        }
    }
    
    func testMissedFailure() throws {
        try assertFailure("failed - bar") {
            try assertFailure("failed - foo") {
                XCTFail("foo")
                XCTFail("bar")
            }
        }
    }
}
