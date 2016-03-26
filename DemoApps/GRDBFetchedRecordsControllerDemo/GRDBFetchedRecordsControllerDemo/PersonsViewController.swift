import UIKit
import GRDB

class PersonsViewController: UITableViewController {
    var personsController: FetchedRecordsController<Person>!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let request = Person.order(SQLColumn("score").desc, SQLColumn("name"))
        personsController = FetchedRecordsController(dbQueue, request: request, compareRecordsByPrimaryKey: true)
        personsController.delegate = self
        personsController.performFetch()
    }
}


// MARK: - Navigation

extension PersonsViewController : PersonEditionViewControllerDelegate {
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "EditPerson" {
            let person = personsController.recordAtIndexPath(self.tableView.indexPathForSelectedRow!)
            let controller = segue.destinationViewController as! PersonEditionViewController
            controller.title = person.name
            controller.person = person
            controller.delegate = self // we will save person when back button is tapped
            controller.cancelButtonHidden = true
            controller.commitButtonHidden = true
        }
        else if segue.identifier == "NewPerson" {
            let navigationController = segue.destinationViewController as! UINavigationController
            let controller = navigationController.viewControllers.first as! PersonEditionViewController
            controller.title = NSLocalizedString("New Person", comment: "")
            controller.person = Person(name: "", score: 0)
        }
    }
    
    @IBAction func cancelPersonEdition(segue: UIStoryboardSegue) {
        // Person creation: cancel button was tapped
    }
    
    @IBAction func commitPersonEdition(segue: UIStoryboardSegue) {
        // Person creation: commit button was tapped
        let controller = segue.sourceViewController as! PersonEditionViewController
        controller.applyChanges()
        if !controller.person.name.isEmpty {
            try! controller.person.save(dbQueue)
        }
    }
    
    func personEditionControllerDidComplete(controller: PersonEditionViewController) {
        // Person edition: back button was tapped
        controller.applyChanges()
        if !controller.person.name.isEmpty {
            try! controller.person.save(dbQueue)
        }
    }
}


// MARK: - UITableViewDataSource

extension PersonsViewController {
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let person = personsController.recordAtIndexPath(indexPath)
        cell.textLabel?.text = person.name
        cell.detailTextLabel?.text = "\(person.score) points"
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return personsController.sections.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return personsController.sections[section].numberOfRecords
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Person", forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
}


// MARK: - FetchedRecordsControllerDelegate

extension PersonsViewController : FetchedRecordsControllerDelegate {
    
    func controllerWillChangeRecords<T>(controller: FetchedRecordsController<T>) {
        tableView.beginUpdates()
    }
    
    func controller<T>(controller: FetchedRecordsController<T>, didChangeRecord record: T, withEvent event:FetchedRecordsEvent) {
        switch event {
        case .Insertion(let indexPath):
            tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            
        case .Deletion(let indexPath):
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            
        case .Update(let indexPath, _):
            if let cell = tableView.cellForRowAtIndexPath(indexPath) {
                configureCell(cell, atIndexPath: indexPath)
            }
            
        case .Move(let indexPath, let newIndexPath, _):
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeRecords<T>(controller: FetchedRecordsController<T>) {
        tableView.endUpdates()
    }
}