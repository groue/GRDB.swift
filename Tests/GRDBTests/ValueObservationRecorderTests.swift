import Dispatch
import XCTest

class ValueObservationRecorderTests: FailureTestCase {
    // MARK: - NextOne
    
    func testNextOneSuccess() throws {
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            try XCTAssertEqual(recorder.next().get(), "foo")
            recorder.onChange("bar")
            try XCTAssertEqual(recorder.next().get(), "bar")
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onChange("bar")
            try XCTAssertEqual(recorder.next().get(), "foo")
            try XCTAssertEqual(recorder.next().get(), "bar")
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onChange("bar")
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 0.5), "foo")
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 0.5), "bar")
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("bar")
                }
            }
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 0.5), "foo")
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 0.5), "bar")
        }
    }
    
    func testNextOneError() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            _ = try recorder.next().get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            _ = try wait(for: recorder.next(), timeout: 0.1)
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onError(CustomError())
            try XCTAssertEqual(recorder.next().get(), "foo")
            do {
                _ = try recorder.next().get()
                XCTFail("Expected error")
            } catch is CustomError { }
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onError(CustomError())
            }
            _ = try wait(for: recorder.next(), timeout: 0.5)
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onError(CustomError())
                }
            }
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 0.5), "foo")
            do {
                _ = try wait(for: recorder.next(), timeout: 0.5)
                XCTFail("Expected error")
            } catch is CustomError { }
        }
    }
    
    func testNextOneTimeout() throws {
        try assertFailure("Asynchronous wait failed") {
            do {
                let recorder = ValueObservationRecorder<String>()
                _ = try wait(for: recorder.next(), timeout: 0.1)
                XCTFail("Expected error")
            } catch ValueRecordingError.notEnoughValues { }
        }
        try assertFailure("Asynchronous wait failed") {
            do {
                let recorder = ValueObservationRecorder<String>()
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("foo")
                }
                try XCTAssertEqual(wait(for: recorder.next(), timeout: 0.5), "foo")
                do {
                    _ = try wait(for: recorder.next(), timeout: 0.5)
                    XCTFail("Expected error")
                } catch ValueRecordingError.notEnoughValues { }
            }
        }
    }
    
    func testNextOneNotEnoughElement() throws {
        do {
            let recorder = ValueObservationRecorder<String>()
            _ = try recorder.next().get()
            XCTFail("Expected error")
        } catch ValueRecordingError.notEnoughValues { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            try XCTAssertEqual(recorder.next().get(), "foo")
            do {
                _ = try recorder.next().get()
                XCTFail("Expected error")
            } catch ValueRecordingError.notEnoughValues { }
        }
    }
    
    // MARK: - NextOne Inverted
    
    func testNextOneInvertedSuccess() throws {
        do {
            let recorder = ValueObservationRecorder<String>()
            try recorder.next().inverted.get()
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            _ = try recorder.next().get()
            try recorder.next().inverted.get()
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
            }
            _ = try wait(for: recorder.next(), timeout: 0.5)
            try wait(for: recorder.next().inverted, timeout: 0.5)
        }
    }
    
    func testNextOneInvertedError() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            try recorder.next().inverted.get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onError(CustomError())
            _ = try recorder.next().get()
            do {
                try recorder.next().inverted.get()
                XCTFail("Expected error")
            } catch is CustomError { }
        }
    }
    
    func testNextOneInvertedTimeout() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
            }
            try assertFailure("Fulfilled inverted expectation") {
                try wait(for: recorder.next().inverted, timeout: 0.5)
            }
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("bar")
                }
            }
            _ = try wait(for: recorder.next(), timeout: 0.5)
            try assertFailure("Fulfilled inverted expectation") {
                try wait(for: recorder.next().inverted, timeout: 0.5)
            }
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onError(CustomError())
            }
            try assertFailure("Fulfilled inverted expectation") {
                do {
                    try wait(for: recorder.next().inverted, timeout: 0.5)
                    XCTFail("Expected error")
                } catch is CustomError { }
            }
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onError(CustomError())
                }
            }
            _ = try wait(for: recorder.next(), timeout: 0.5)
            try assertFailure("Fulfilled inverted expectation") {
                do {
                    try wait(for: recorder.next().inverted, timeout: 0.5)
                    XCTFail("Expected error")
                } catch is CustomError { }
            }
        }
    }
    
    // MARK: - Next
    
    func testNextSuccess() throws {
        do {
            let recorder = ValueObservationRecorder<String>()
            try XCTAssertEqual(recorder.next(0).get(), [])
            recorder.onChange("foo")
            try XCTAssertEqual(recorder.next(1).get(), ["foo"])
            recorder.onChange("bar")
            recorder.onChange("baz")
            try XCTAssertEqual(recorder.next(2).get(), ["bar", "baz"])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onChange("bar")
            try XCTAssertEqual(recorder.next(1).get(), ["foo"])
            recorder.onChange("baz")
            try XCTAssertEqual(recorder.next(2).get(), ["bar", "baz"])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("bar")
                }
            }
            try XCTAssertEqual(wait(for: recorder.next(2), timeout: 0.5), ["foo", "bar"])
        }
    }
    
    func testNextError() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            _ = try recorder.next(2).get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onError(CustomError())
            _ = try recorder.next(2).get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onError(CustomError())
            }
            _ = try wait(for: recorder.next(2), timeout: 0.5)
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onError(CustomError())
                }
            }
            _ = try wait(for: recorder.next(2), timeout: 0.5)
            XCTFail("Expected error")
        } catch is CustomError { }
    }
    
    func testNextTimeout() throws {
        try assertFailure("Asynchronous wait failed") {
            do {
                let recorder = ValueObservationRecorder<String>()
                _ = try wait(for: recorder.next(2), timeout: 0.1)
                XCTFail("Expected error")
            } catch ValueRecordingError.notEnoughValues { }
        }
        try assertFailure("Asynchronous wait failed") {
            do {
                let recorder = ValueObservationRecorder<String>()
                recorder.onChange("foo")
                _ = try wait(for: recorder.next(2), timeout: 0.1)
                XCTFail("Expected error")
            } catch ValueRecordingError.notEnoughValues { }
        }
        try assertFailure("Asynchronous wait failed") {
            do {
                let recorder = ValueObservationRecorder<String>()
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("foo")
                }
                _ = try wait(for: recorder.next(2), timeout: 0.5)
                XCTFail("Expected error")
            } catch ValueRecordingError.notEnoughValues { }
        }
    }
    
    func testNextNotEnoughElement() throws {
        do {
            let recorder = ValueObservationRecorder<String>()
            _ = try recorder.next(2).get()
            XCTFail("Expected error")
        } catch ValueRecordingError.notEnoughValues { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            _ = try recorder.next(2).get()
            XCTFail("Expected error")
        } catch ValueRecordingError.notEnoughValues { }
    }
    
    // MARK: - Prefix(maxLength)
    
    func testPrefixMaxLengthSuccess() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            try XCTAssertEqual(recorder.prefix(0).get(), [])
            recorder.onChange("foo")
            try XCTAssertEqual(recorder.prefix(0).get(), [])
            try XCTAssertEqual(recorder.prefix(1).get(), ["foo"])
            recorder.onChange("bar")
            recorder.onChange("baz")
            try XCTAssertEqual(recorder.prefix(0).get(), [])
            try XCTAssertEqual(recorder.prefix(1).get(), ["foo"])
            try XCTAssertEqual(recorder.prefix(2).get(), ["foo", "bar"])
            try XCTAssertEqual(recorder.prefix(3).get(), ["foo", "bar", "baz"])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            try XCTAssertEqual(recorder.prefix(0).get(), [])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onError(CustomError())
            try XCTAssertEqual(recorder.prefix(1).get(), ["foo"])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("bar")
                }
            }
            try XCTAssertEqual(wait(for: recorder.prefix(2), timeout: 0.5), ["foo", "bar"])
        }
    }
    
    func testPrefixMaxLengthError() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            _ = try recorder.prefix(2).get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onError(CustomError())
            _ = try recorder.prefix(2).get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onError(CustomError())
            }
            _ = try wait(for: recorder.prefix(2), timeout: 0.5)
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onError(CustomError())
                }
            }
            _ = try wait(for: recorder.prefix(2), timeout: 0.5)
            XCTFail("Expected error")
        } catch is CustomError { }
    }
    
    func testPrefixMaxLengthTimeout() throws {
        try assertFailure("Asynchronous wait failed") {
            let recorder = ValueObservationRecorder<String>()
            let values = try wait(for: recorder.prefix(2), timeout: 0.1)
            XCTAssertEqual(values, [])
        }
        try assertFailure("Asynchronous wait failed") {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            let values = try wait(for: recorder.prefix(2), timeout: 0.1)
            XCTAssertEqual(values, ["foo"])
        }
        try assertFailure("Asynchronous wait failed") {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
            }
            let values = try wait(for: recorder.prefix(2), timeout: 0.5)
            XCTAssertEqual(values, ["foo"])
        }
    }
    
    // MARK: - Prefix(maxLength) Inverted
    
    func testPrefixMaxLengthInvertedSuccess() throws {
        do {
            let recorder = ValueObservationRecorder<String>()
            try XCTAssertEqual(recorder.prefix(1).inverted.get(), [])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            try XCTAssertEqual(recorder.prefix(2).inverted.get(), ["foo"])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
            }
            try XCTAssertEqual(wait(for: recorder.prefix(2).inverted, timeout: 0.5), ["foo"])
        }
    }
    
    func testPrefixMaxLengthInvertedError() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            _ = try recorder.prefix(1).inverted.get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onError(CustomError())
            _ = try recorder.prefix(2).inverted.get()
            XCTFail("Expected error")
        } catch is CustomError { }
    }
    
    func testPrefixMaxLengthInvertedTimeout() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
            }
            try assertFailure("Fulfilled inverted expectation") {
                _ = try wait(for: recorder.prefix(1).inverted, timeout: 0.5)
            }
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("bar")
                }
            }
            try assertFailure("Fulfilled inverted expectation") {
                _ = try wait(for: recorder.prefix(2).inverted, timeout: 0.5)
            }
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onError(CustomError())
            }
            try assertFailure("Fulfilled inverted expectation") {
                do {
                    _ = try wait(for: recorder.prefix(1).inverted, timeout: 0.5)
                    XCTFail("Expected error")
                } catch is CustomError { }
            }
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onError(CustomError())
                }
            }
            try assertFailure("Fulfilled inverted expectation") {
                do {
                    _ = try wait(for: recorder.prefix(2).inverted, timeout: 0.5)
                    XCTFail("Expected error")
                } catch is CustomError { }
            }
        }
    }
    
    // MARK: - Prefix(maxLength)
    
    func testPrefixUntilSuccess() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            try XCTAssertEqual(recorder.prefix(until: { $0 == "foo" }).get(), ["foo"])
            recorder.onChange("bar")
            recorder.onChange("baz")
            try XCTAssertEqual(recorder.prefix(until: { $0 == "foo" }).get(), ["foo"])
            try XCTAssertEqual(recorder.prefix(until: { $0 == "bar" }).get(), ["foo", "bar"])
            try XCTAssertEqual(recorder.prefix(until: { $0 == "baz" }).get(), ["foo", "bar", "baz"])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onError(CustomError())
            try XCTAssertEqual(recorder.prefix(until: { $0 == "foo" }).get(), ["foo"])
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("bar")
                }
            }
            try XCTAssertEqual(wait(for: recorder.prefix(until: { $0 == "bar" }), timeout: 0.5), ["foo", "bar"])
        }
    }
    
    func testPrefixUntilError() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            _ = try recorder.prefix(until: { $0 == "bar" }).get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            recorder.onError(CustomError())
            _ = try recorder.prefix(until: { $0 == "bar" }).get()
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onError(CustomError())
            }
            _ = try wait(for: recorder.prefix(until: { $0 == "bar" }), timeout: 0.5)
            XCTFail("Expected error")
        } catch is CustomError { }
        do {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onError(CustomError())
                }
            }
            _ = try wait(for: recorder.prefix(until: { $0 == "bar" }), timeout: 0.5)
            XCTFail("Expected error")
        } catch is CustomError { }
    }
    
    func testPrefixUntilTimeout() throws {
        try assertFailure("Asynchronous wait failed") {
            let recorder = ValueObservationRecorder<String>()
            let values = try wait(for: recorder.prefix(until: { $0 == "bar" }), timeout: 0.1)
            XCTAssertEqual(values, [])
        }
        try assertFailure("Asynchronous wait failed") {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            let values = try wait(for: recorder.prefix(until: { $0 == "bar" }), timeout: 0.1)
            XCTAssertEqual(values, ["foo"])
        }
        try assertFailure("Asynchronous wait failed") {
            let recorder = ValueObservationRecorder<String>()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                recorder.onChange("foo")
            }
            let values = try wait(for: recorder.prefix(until: { $0 == "bar" }), timeout: 0.5)
            XCTAssertEqual(values, ["foo"])
        }
    }
    
    // MARK: - Failure
    
    func testFailureSuccess() throws {
        struct CustomError: Error { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            let (elements, error) = try recorder.failure().get()
            XCTAssertEqual(elements, [])
            XCTAssert(error is CustomError)
        }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onError(CustomError())
            let (elements, error) = try wait(for: recorder.failure(), timeout: 0.1)
            XCTAssertEqual(elements, [])
            XCTAssert(error is CustomError)
        }
    }
    
    func testFailureTimeout() throws {
        try assertFailure("Asynchronous wait failed") {
            do {
                let recorder = ValueObservationRecorder<String>()
                _ = try wait(for: recorder.failure(), timeout: 0.1)
                XCTFail("Expected error")
            } catch ValueRecordingError.notFailed { }
        }
        try assertFailure("Asynchronous wait failed") {
            do {
                let recorder = ValueObservationRecorder<String>()
                recorder.onChange("foo")
                _ = try wait(for: recorder.failure(), timeout: 0.1)
                XCTFail("Expected error")
            } catch ValueRecordingError.notFailed { }
        }
        try assertFailure("Asynchronous wait failed") {
            do {
                let recorder = ValueObservationRecorder<String>()
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(10)) {
                    recorder.onChange("foo")
                }
                _ = try wait(for: recorder.failure(), timeout: 0.5)
                XCTFail("Expected error")
            } catch ValueRecordingError.notFailed { }
        }
    }
    
    func testFailureNotFailed() throws {
        do {
            let recorder = ValueObservationRecorder<String>()
            _ = try recorder.failure().get()
            XCTFail("Expected error")
        } catch ValueRecordingError.notFailed { }
        do {
            let recorder = ValueObservationRecorder<String>()
            recorder.onChange("foo")
            _ = try recorder.failure().get()
            XCTFail("Expected error")
        } catch ValueRecordingError.notFailed { }
    }
    
    // MARK: - assertValueObservationRecordingMatch
    
    func testAssertValueObservationRecordingMatch() {
        do {
            let expected = [3]
            assertValueObservationRecordingMatch(recorded: [3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [3, 3], expected: expected)
            assertFailure("failed - missing expected value 3") {
                assertValueObservationRecordingMatch(recorded: [], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [2]", "failed - missing expected value 3") {
                assertValueObservationRecordingMatch(recorded: [2], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [2]") {
                assertValueObservationRecordingMatch(recorded: [2, 3], expected: expected)
            }
        }
        do {
            let expected = [2, 3]
            assertValueObservationRecordingMatch(recorded: [3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [3, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [3, 3, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [2, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [2, 2, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [2, 2, 3, 3], expected: expected)
            assertFailure("failed - missing expected value 3") {
                assertValueObservationRecordingMatch(recorded: [], expected: expected)
            }
            assertFailure("failed - missing expected value 3") {
                assertValueObservationRecordingMatch(recorded: [2], expected: expected)
            }
            assertFailure("failed - missing expected value 3", "failed - unexpected recorded prefix [3]") {
                assertValueObservationRecordingMatch(recorded: [3, 2], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [1]") {
                assertValueObservationRecordingMatch(recorded: [1, 3], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [1]") {
                assertValueObservationRecordingMatch(recorded: [1, 2, 3], expected: expected)
            }
        }
        do {
            let expected = [3, 3]
            assertValueObservationRecordingMatch(recorded: [3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [3, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [3, 3, 3], expected: expected)
            assertFailure("failed - missing expected value 3") {
                assertValueObservationRecordingMatch(recorded: [], expected: expected)
            }
            assertFailure("failed - missing expected value 3", "failed - unexpected recorded prefix [2]") {
                assertValueObservationRecordingMatch(recorded: [2], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [2]") {
                assertValueObservationRecordingMatch(recorded: [2, 3], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [2, 2]") {
                assertValueObservationRecordingMatch(recorded: [2, 2, 3], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [1, 2]") {
                assertValueObservationRecordingMatch(recorded: [1, 2, 3], expected: expected)
            }
        }
        do {
            let expected = [1, 2, 2, 3]
            assertValueObservationRecordingMatch(recorded: [3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [3, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 3, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 1, 3, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 2, 2, 3], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 2, 3], expected: expected)
            assertFailure("failed - missing expected value 3") {
                assertValueObservationRecordingMatch(recorded: [], expected: expected)
            }
            assertFailure("failed - missing expected value 3") {
                assertValueObservationRecordingMatch(recorded: [2], expected: expected)
            }
            assertFailure("failed - missing expected value 3", "failed - unexpected recorded prefix [3]") {
                assertValueObservationRecordingMatch(recorded: [3, 2], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [2]") {
                assertValueObservationRecordingMatch(recorded: [2, 1, 3], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [0]") {
                assertValueObservationRecordingMatch(recorded: [0, 3], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [0]") {
                assertValueObservationRecordingMatch(recorded: [0, 1, 2, 3], expected: expected)
            }
        }
        do {
            let expected = [1, 2, 1]
            assertValueObservationRecordingMatch(recorded: [1], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 1], expected: expected)
            assertValueObservationRecordingMatch(recorded: [2, 1], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 2, 1], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 1, 2, 1], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 2, 1, 1], expected: expected)
            assertValueObservationRecordingMatch(recorded: [1, 2, 2, 1], expected: expected)
            assertFailure("failed - missing expected value 1") {
                assertValueObservationRecordingMatch(recorded: [], expected: expected)
            }
            assertFailure("failed - missing expected value 1") {
                assertValueObservationRecordingMatch(recorded: [2], expected: expected)
            }
            assertFailure("failed - missing expected value 1") {
                assertValueObservationRecordingMatch(recorded: [1, 2], expected: expected)
            }
            assertFailure("failed - unexpected recorded prefix [0]") {
                assertValueObservationRecordingMatch(recorded: [0, 1], expected: expected)
            }
        }
    }
}
