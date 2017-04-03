import UIKit
import GRDBCipher

class ViewController: UIViewController {
    @IBOutlet weak var SQLiteVersionLabel: UILabel!
    @IBOutlet weak var personCountLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sqliteVersion = String(cString: sqlite3_libversion(), encoding: .utf8)!
        SQLiteVersionLabel.text = "SQLite version: \(sqliteVersion)"
        
        let personCount = try! dbQueue.inDatabase { try Person.fetchCount($0) }
        personCountLabel.text = "Number of persons: \(personCount)"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
