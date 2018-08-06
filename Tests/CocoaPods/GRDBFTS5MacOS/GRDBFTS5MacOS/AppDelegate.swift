import Cocoa
import GRDB

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let dbQueue = DatabaseQueue()
        try! dbQueue.write { db in
            // Test access to FTS5 C API
            _ = try db.makeTokenizer(.unicode61())
            
            // Test creation of FTS5 table
            try db.create(virtualTable: "document", using: FTS5()) { t in
                t.column("content")
            }
        }
    }
}

