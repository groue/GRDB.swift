import Dispatch
import GRDB
import UserNotifications

class Tests {
    static let shared = Tests()
    
    func next() -> (Int, Test)? {
        iterator.next()
    }
    
    private let tests: [Test] = [
        testCrash(),
        testImmediateTransaction(),
    ]
    
    private lazy var iterator: EnumeratedSequence<[Test]>.Iterator = { tests.enumerated().makeIterator() }()
    
    private static func testCrash() -> Test {
        var promise: (() -> Void)?
        let semaphore = DispatchSemaphore(value: 0)
        var error: Error?
        return Test(
            title: "Crash",
            instructions: """
                0xDEAD10CC is an exception that crashes your application \
                if a database stored in an App Group container is locked \
                when the application gets suspended.
                
                The first test is asserting that this app can indeed \
                crash with 0xDEAD10CC.
                
                1. Launch this app on a device
                2. Launch the Console application on the Mac
                3. Filter logs on AppGroupTest
                4. Send the app to bacground
                
                EXPECTED: the Console contains "0xDEAD10CC"
                
                When the expectation is fulfilled, relanch the app and \
                hit Done.
                """,
            enter: {
                try AppDatabase.shared.createDatabaseQueue(configuration: Configuration())
                AppDatabase.shared.openTransaction(
                    .immediate,
                    until: { promise = $0 },
                    completion: {
                        error = $0.error
                        semaphore.signal()
                })
        },
            leave: { completion in
                promise?()
                DispatchQueue.global().async {
                    semaphore.wait()
                    completion(error)
                }
        })
    }
    
    private static func testImmediateTransaction() -> Test {
        var promise: (() -> Void)?
        let semaphore = DispatchSemaphore(value: 0)
        var error: Error?
        var handler: NSObjectProtocol?
        _ = handler
        handler = NotificationCenter.default.addObserver(forName: DatabaseBackgroundScheduler.databaseWillSuspendNotification, object: nil, queue: .main) { _ in
            let content = UNMutableNotificationContent()
            content.title = "Test has passed!"
            // Make sure app gets suspended for good
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            handler = nil
        }
        return Test(
            title: "Immediate Transaction",
            instructions: """
                1. Send the app to bacground
                2. Wait for the notification (around 1mn on iOS 13)
                3. Activate the app
                
                EXPECTED: the notification was displayed, and the app is \
                still running.
                """,
            enter: {
                UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions.alert) { _, _ in
                    var configuration = Configuration()
                    configuration.suspendsOnBackgroundTimeExpiration = true
                    try! AppDatabase.shared.createDatabaseQueue(configuration: configuration)
                    AppDatabase.shared.openTransaction(
                        .immediate,
                        until: { promise = $0 },
                        completion: {
                            error = $0.error
                            semaphore.signal() })
                }
        },
            leave: { completion in
                handler = nil
                promise?()
                DispatchQueue.global().async {
                    semaphore.wait()
                    if let error = error {
                        if let dbError = error as? DatabaseError, dbError.isDatabaseSuspensionError {
                            completion(nil)
                        } else {
                            completion(error)
                        }
                    } else {
                        completion(NSError(domain: "GRDB", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Expected suspension error", comment: "")]))
                    }
                    completion(error)
                }
        })
    }
}

extension Result {
    var error: Failure? {
        if case let .failure(error) = self {
            return error
        } else {
            return nil
        }
    }
}
