import Cocoa
import GRDBCipher

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let dbQueue = DatabaseQueue()
        
        // Make sure FTS5 is enabled
        try! dbQueue.write { db in
            try db.create(virtualTable: "document", using: FTS5()) { t in
                t.column("content")
            }
        }
    }
}
