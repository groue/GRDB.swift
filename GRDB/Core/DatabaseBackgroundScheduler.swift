#if os(iOS)
import Dispatch
import Foundation
import UIKit

// TODO: doc
public class DatabaseBackgroundScheduler {
    // TODO: doc
    public static let shared = DatabaseBackgroundScheduler()
    
    // TODO: doc
    public static let databaseWillSuspendNotification = Notification.Name("GRDBDatabaseWillSuspend")
    
    // TODO: doc
    public static let databaseDidResumeNotification = Notification.Name("GRDBDatabaseDidResume")
    
    static let suspendNotification = Notification.Name("GRDBSuspend")
    static let resumeNotification = Notification.Name("GRDBResume")
    
    private var lock = NSLock()
    private var suspendedSemaphore: DispatchSemaphore?
    private var isSuspended = false {
        didSet {
            guard isSuspended != oldValue else { return }
            let center = NotificationCenter.default
            if isSuspended {
                center.post(name: DatabaseBackgroundScheduler.databaseWillSuspendNotification, object: self)
                center.post(name: DatabaseBackgroundScheduler.suspendNotification, object: self)
            } else {
                center.post(name: DatabaseBackgroundScheduler.resumeNotification, object: self)
                center.post(name: DatabaseBackgroundScheduler.databaseDidResumeNotification, object: self)
            }
        }
    }
    
    private init() {
        // We do not listen for UIApplication.willEnterForegroundNotification,
        // because app delegate gets applicationWillBecomeActive(_:) *first*.
        //
        // We can thus *not* make sure the database is resumed before the
        // application attempts at accessing the database.
        //
        // I don't like "smart" APIs that work only sometimes. Instead, we ask
        // the user to explicitely call `resume(in:)` in all system callbacks of
        // app or scene delegate.
        //
        //      func applicationWillEnterForeground(_ application: UIApplication) {
        //          DatabaseBackgroundScheduler.shared.resume(in: application)
        //      }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DatabaseBackgroundScheduler.applicationDidEnterBackground(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        
        // We do not know if self is initialized from an active, inactive, or
        // background application.
        // Just in case, start a background task and wait for notification of
        // imminent application suspension.
        synchronized {
            waitForBackgroundTaskExpiration()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // TODO: doc
    public func resume(in application: UIApplication) {
        synchronized {
            switch application.applicationState {
            case .active, .inactive:
                suspendedSemaphore?.signal()
                suspendedSemaphore = nil
                isSuspended = false
            case .background:
                waitForBackgroundTaskExpiration()
            }
        }
    }
    
    private func synchronized<T>(_ execute: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try execute()
    }
    
    @objc
    func applicationDidEnterBackground(_ notification: Notification) {
        synchronized {
            waitForBackgroundTaskExpiration()
        }
    }
    
    /// MUST be called from a synchronized block
    private func waitForBackgroundTaskExpiration() {
        suspendedSemaphore?.signal()
        isSuspended = false
        
        let semaphore = DispatchSemaphore(value: 0)
        ProcessInfo.processInfo.performExpiringActivity(withReason: "GRDB.DatabaseTaskScheduler") { suspended in
            if suspended {
                self.synchronized {
                    self.suspendedSemaphore?.signal()
                    self.suspendedSemaphore = nil
                    self.isSuspended = true
                }
            } else {
                semaphore.wait()
            }
        }
        
        suspendedSemaphore = semaphore
    }
}
#endif
