import Cocoa
import GRDB

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Make sure SQLCipher is enabled
        var configuration = Configuration()
        configuration.passphrase = "secret"
        let dbQueue = DatabaseQueue(configuration: configuration)
        
        // Make sure FTS5 is enabled
        try! dbQueue.write { db in
            try db.create(virtualTable: "document", using: FTS5()) { t in
                t.column("content")
            }
        }
    }
}
