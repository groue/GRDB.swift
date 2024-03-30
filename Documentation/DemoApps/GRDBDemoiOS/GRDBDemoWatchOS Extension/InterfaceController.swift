import WatchKit
import Foundation
import GRDB
import SQLite3

class InterfaceController: WKInterfaceController {
    
    @IBOutlet var versionLabel: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        let sqliteVersion = String(cString: sqlite3_libversion(), encoding: .utf8)
        versionLabel.setText(sqliteVersion)
    }
}
