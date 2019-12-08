#if os(iOS)
import Dispatch
import Foundation
import UIKit

/// DatabaseBackgroundScheduler takes care of suspending databases before the
/// application enters the suspended state, in order to avoid the [`0xdead10cc`
/// exception](https://developer.apple.com/library/archive/technotes/tn2151/_index.html).
///
/// See `Configuration.suspendsOnBackgroundTimeExpiration` for more information.
public class DatabaseBackgroundScheduler {
    /// The shared DatabaseBackgroundScheduler
    public static let shared = DatabaseBackgroundScheduler()
    
    /// This notification is posted immediately before databases get suspended.
    ///
    /// See `Configuration.suspendsOnBackgroundTimeExpiration` for more information.
    public static let databaseWillSuspendNotification = Notification.Name("GRDBDatabaseWillSuspend")
    
    /// This notification is posted immediately after databases are resumed.
    ///
    /// See `Configuration.suspendsOnBackgroundTimeExpiration` for more information.
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
    
    /// Resumes database that were suspended before the application last entered
    /// the suspended state.
    ///
    /// The only time it's safe to call this method is in exactly the same
    /// runloop cycle as your app is woken by the system. For example, you will
    /// call `resume(in:)` in `UIApplicationDelegate.applicationWillEnterForeground(_:)`
    /// or `SceneDelegate.sceneWillEnterForeground(_:)`, and in the various
    /// background mode callbacks defined by iOS.
    ///
    /// For example:
    ///
    ///     @UIApplicationMain
    ///     class AppDelegate: UIResponder, UIApplicationDelegate {
    ///         func applicationWillEnterForeground(_ application: UIApplication) {
    ///             // Resume suspended databases
    ///             DatabaseBackgroundScheduler.shared.resume(in: application)
    ///         }
    ///     }
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
    
    // TODO: what about apps that do not want to run in the background?
    /// MUST be called from a synchronized block
    private func waitForBackgroundTaskExpiration() {
        suspendedSemaphore?.signal()
        isSuspended = false
        
        let semaphore = DispatchSemaphore(value: 0)
        ProcessInfo.processInfo.performExpiringActivity(withReason: "GRDB.DatabaseBackgroundScheduler") { suspended in
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
