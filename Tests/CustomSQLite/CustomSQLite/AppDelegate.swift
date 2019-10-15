import Cocoa
import GRDBCustomSQLite

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        _ = DatabaseQueue()
        _ = FTS5()
        _ = sqlite3_preupdate_new(nil, 0, nil)
    }
}
