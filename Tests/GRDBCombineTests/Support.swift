#if canImport(Combine)
import Combine
import Foundation
import XCTest

final class Test<Context> {
    // Raise the repeatCount in order to help spotting flaky tests.
    private let repeatCount: Int
    private let test: (Context, Int) throws -> ()
    
    init(repeatCount: Int = 1, _ test: @escaping (Context) throws -> ()) {
        self.repeatCount = repeatCount
        self.test = { context, _ in try test(context) }
    }
    
    init(repeatCount: Int, _ test: @escaping (Context, Int) throws -> ()) {
        self.repeatCount = repeatCount
        self.test = test
    }
    
    @discardableResult
    func run(context: () throws -> Context) throws -> Self {
        for i in 1...repeatCount {
            try test(context(), i)
        }
        return self
    }
    
    @discardableResult
    func runInTemporaryDirectory(context: (_ directoryURL: URL) throws -> Context) throws -> Self {
        for i in 1...repeatCount {
            let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GRDB", isDirectory: true)
                .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
            
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            defer {
                try! FileManager.default.removeItem(at: directoryURL)
            }
            
            try test(context(directoryURL), i)
        }
        return self
    }
    
    @discardableResult
    func runAtTemporaryDatabasePath(context: (_ path: String) throws -> Context) throws -> Self {
        try runInTemporaryDirectory { url in
            try context(url.appendingPathComponent("db.sqlite").path)
        }
    }
}

#if compiler(>=5.3)
@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func assertNoFailure<Failure>(
    _ completion: Subscribers.Completion<Failure>,
    file: StaticString = #filePath,
    line: UInt = #line)
{
    if case let .failure(error) = completion {
        XCTFail("Unexpected completion failure: \(error)", file: file, line: line)
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func assertFailure<Failure, ExpectedFailure>(
    _ completion: Subscribers.Completion<Failure>,
    file: StaticString = #filePath,
    line: UInt = #line,
    test: (ExpectedFailure) -> Void)
{
    if case let .failure(error) = completion, let expectedError = error as? ExpectedFailure {
        test(expectedError)
    } else {
        XCTFail("Expected \(ExpectedFailure.self), got \(completion)", file: file, line: line)
    }
}
#else
@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func assertNoFailure<Failure>(
    _ completion: Subscribers.Completion<Failure>,
    file: StaticString = #file,
    line: UInt = #line)
{
    if case let .failure(error) = completion {
        XCTFail("Unexpected completion failure: \(error)", file: file, line: line)
    }
}

@available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func assertFailure<Failure, ExpectedFailure>(
    _ completion: Subscribers.Completion<Failure>,
    file: StaticString = #file,
    line: UInt = #line,
    test: (ExpectedFailure) -> Void)
{
    if case let .failure(error) = completion, let expectedError = error as? ExpectedFailure {
        test(expectedError)
    } else {
        XCTFail("Expected \(ExpectedFailure.self), got \(completion)", file: file, line: line)
    }
}
#endif
#endif

