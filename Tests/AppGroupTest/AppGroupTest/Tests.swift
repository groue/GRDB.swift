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
        testEnd()
    ]
    
    private lazy var iterator: EnumeratedSequence<[Test]>.Iterator = { tests.enumerated().makeIterator() }()
    
    private static func testCrash() -> Test {
        var commitTransaction: (() -> Void)?
        let transactionCompletion = DispatchSemaphore(value: 0)
        var transactionError: Error?
        
        func enter() throws {
            try AppDatabase.shared.createDatabaseQueue(configuration: Configuration())
            AppDatabase.shared.openTransaction(
                .immediate,
                until: { commitTransaction = $0 },
                completion: {
                    transactionError = $0.error
                    transactionCompletion.signal()
            })
        }
        
        func leave(_ completion: @escaping (Error?) -> Void) {
            commitTransaction?()
            DispatchQueue.global().async {
                transactionCompletion.wait()
                completion(transactionError)
            }
        }
        
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
            enter: enter,
            leave: leave)
    }
    
    private static func testImmediateTransaction() -> Test {
        var commitTransaction: (() -> Void)?
        let transactionCompletion = DispatchSemaphore(value: 0)
        var transactionError: Error?
        var databaseWillSuspendToken: NSObjectProtocol?
        _ = databaseWillSuspendToken
        
        func enter() {
            UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions.alert) { _, _ in
                var configuration = Configuration()
                configuration.suspendsOnBackgroundTimeExpiration = true
                try! AppDatabase.shared.createDatabaseQueue(configuration: configuration)
                
                AppDatabase.shared.openTransaction(
                    .immediate,
                    until: { commitTransaction = $0 },
                    completion: {
                        transactionError = $0.error
                        transactionCompletion.signal() })
                
                databaseWillSuspendToken = NotificationCenter.default.addObserver(
                    forName: DatabaseBackgroundScheduler.databaseWillSuspendNotification,
                    object: nil,
                    queue: .main,
                    using: databaseWillSuspend)
                
            }
        }
        
        func databaseWillSuspend(_ notification: Notification) {
            let content = UNMutableNotificationContent()
            content.title = "Please wake up the application"
            // Make sure app gets suspended for good
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            databaseWillSuspendToken = nil
        }
        
        func leave(_ completion: @escaping (Error?) -> Void) {
            databaseWillSuspendToken = nil
            commitTransaction?()
            DispatchQueue.global().async {
                transactionCompletion.wait()
                if let dbError = transactionError as? DatabaseError, dbError.isDatabaseSuspensionError {
                    // That's what we expect.
                    // Now check that database is still usable, thanks to
                    // SceneDelegate.sceneWillEnterForeground(_:)
                    do {
                        try AppDatabase.shared.dbWriter!.write { db in
                            try db.execute(sql: "CREATE TABLE t(a)")
                        }
                        completion(nil)
                    } catch {
                        completion(error)
                    }
                } else {
                    completion(transactionError ?? NSError(
                        domain: "GRDB",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Expected suspension error", comment: "")]))
                }
            }
        }
        
        return Test(
            title: "Immediate Transaction",
            instructions: """
                1. Accept notifications
                2. Send the app to bacground
                3. Wait for the notification (around 1mn on iOS 13)
                4. Activate the app
                
                EXPECTED: the notification was displayed, and the app is \
                still running.
                """,
            enter: enter,
            leave: leave)
    }
    
    private static func testEnd() -> Test {
        Test(
            title: NSLocalizedString("Thank you!", comment: ""),
            instructions: NSLocalizedString("Tests are completed.", comment: ""),
            enter: { },
            leave: { $0(nil) })
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
