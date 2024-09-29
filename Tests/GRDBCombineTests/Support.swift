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

final class AsyncTest<Context> {
    // Raise the repeatCount in order to help spotting flaky tests.
    private let repeatCount: Int
    private let test: (Context, Int) async throws -> ()
    
    init(repeatCount: Int = 1, _ test: @escaping (Context) async throws -> ()) {
        self.repeatCount = repeatCount
        self.test = { context, _ in try await test(context) }
    }
    
    init(repeatCount: Int, _ test: @escaping (Context, Int) async throws -> ()) {
        self.repeatCount = repeatCount
        self.test = test
    }
    
    @discardableResult
    func run(context: () async throws -> Context) async throws -> Self {
        for i in 1...repeatCount {
            try await test(context(), i)
        }
        return self
    }
    
    @discardableResult
    func runInTemporaryDirectory(context: (_ directoryURL: URL) async throws -> Context) async throws -> Self {
        for i in 1...repeatCount {
            let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GRDB", isDirectory: true)
                .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
            
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            defer {
                try! FileManager.default.removeItem(at: directoryURL)
            }
            
            try await test(context(directoryURL), i)
        }
        return self
    }
    
    @discardableResult
    func runAtTemporaryDatabasePath(context: (_ path: String) async throws -> Context) async throws -> Self {
        try await runInTemporaryDirectory { url in
            try await context(url.appendingPathComponent("db.sqlite").path)
        }
    }
}

public func assertNoFailure<Failure>(
    _ completion: Subscribers.Completion<Failure>,
    file: StaticString = #file,
    line: UInt = #line)
{
    if case let .failure(error) = completion {
        XCTFail("Unexpected completion failure: \(error)", file: file, line: line)
    }
}

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

