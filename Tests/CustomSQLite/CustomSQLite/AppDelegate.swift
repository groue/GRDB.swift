import Cocoa
import GRDB

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        _ = try! DatabaseQueue()
        _ = FTS5()
        _ = sqlite3_preupdate_new(nil, 0, nil)
        let sqliteVersion = String(cString: sqlite3_libversion())
        print(sqliteVersion)
    }
}
