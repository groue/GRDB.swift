import WatchKit
import GRDB

class InterfaceController: WKInterfaceController {

    @IBOutlet var table: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        let persons = dbQueue.inDatabase { db in
            Person.order(Column("name")).fetchAll(db)
        }
        
        table.setNumberOfRows(persons.count, withRowType: "Person")
        for (i, person) in persons.enumerated() {
            let row = table.rowController(at: i) as! PersonRowController
            row.nameLabel.setText(person.name)
        }
    }
}

class PersonRowController: NSObject {
    @IBOutlet var nameLabel: WKInterfaceLabel!
}
