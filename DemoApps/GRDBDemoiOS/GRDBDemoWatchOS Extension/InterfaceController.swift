import WatchKit
import GRDB

class InterfaceController: WKInterfaceController {

    @IBOutlet var table: WKInterfaceTable!
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        let persons = dbQueue.inDatabase { db in
            Person.order(SQLColumn("name")).fetchAll(db)
        }
        
        table.setNumberOfRows(persons.count, withRowType: "Person")
        for (i, person) in persons.enumerate() {
            let row = table.rowControllerAtIndex(i) as! PersonRowController
            row.nameLabel.setText(person.name)
        }
    }
}

class PersonRowController: NSObject {
    @IBOutlet var nameLabel: WKInterfaceLabel!
}
