import UIKit
import GRDB

class MasterViewController: UITableViewController {
    var detailViewController: DetailViewController? = nil
    var fetchedRecordsController: FetchedRecordsController<Person>!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = self.editButtonItem()
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Swap Names", style: UIBarButtonItemStyle.Done, target: self, action: "swapNames"),
            UIBarButtonItem(title: "Shuffle", style: UIBarButtonItemStyle.Done, target: self, action: "shufflePersons"),
            UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        ]
        self.navigationController?.toolbarHidden = false
        
        // The fetched objects
        let fetchRequest = Person.filter(Col.visible).order(Col.position, Col.firstName, Col.lastName)
        fetchedRecordsController = FetchedRecordsController(dbQueue, fetchRequest)
        
        fetchedRecordsController.willChange { [unowned self] in
            // Events are about to be applied
            print("-----------------------------------------------------------")
            print("BEFORE \(self.fetchedRecordsController.fetchedRecords!.map { ["id":$0.id, "position":$0.position] })")
            self.tableView.beginUpdates()
        }
        
        fetchedRecordsController.onEvent { [unowned self] (person, event) in
            // Apply individual event
            print(event)
            switch event {
            case .Insertion(let indexPath):
                self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                
            case .Deletion(let indexPath):
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
                
            case .Move(let indexPath, let newIndexPath, let changes):
//                // Technique 1 (replace)
//                //
//                // TODO: fix crash
//                //
//                //      BEFORE [["id": 6, "position": 3], ["id": 5, "position": 5], ["id": 14, "position": 6], ["id": 1, "position": 9], ["id": 7, "position": 11], ["id": 9, "position": 15], ["id": 12, "position": 19], ["id": 4, "position": 22]]
//                //      DELETED FROM index 1
//                //      DELETED FROM index 3
//                //      INSERTED AT index 3
//                //      MOVED FROM index 6 TO index 1 WITH CHANGES: ["position": 10]
//                //      DELETED FROM index 7
//                //      DELETED FROM index 8
//                //      DELETED FROM index 9
//                //      DELETED FROM index 10
//                //      DELETED FROM index 11
//                //      DELETED FROM index 12
//                //      MOVED FROM index 13 TO index 0 WITH CHANGES: ["position": 20]
//                //      INSERTED AT index 5
//                //      DELETED FROM index 14
//                //      MOVED FROM index 2 TO index 6 WITH CHANGES: ["position": 4]
//                //      DELETED FROM index 15
//                //      MOVED FROM index 5 TO index 7 WITH CHANGES: ["position": 9]
//                //      AFTER [["id": 19, "position": 0], ["id": 3, "position": 1], ["id": 2, "position": 2], ["id": 4, "position": 5], ["id": 1, "position": 7], ["id": 7, "position": 14], ["id": 13, "position": 15], ["id": 10, "position": 21]]
//                self.tableView.deleteRowsAtIndexPaths([indexPath],
//                    withRowAnimation: UITableViewRowAnimation.Fade)
//                self.tableView.insertRowsAtIndexPaths([newIndexPath],
//                    withRowAnimation: UITableViewRowAnimation.Fade)
                
                // Technique 2 (move & update)
                //
                // TODO: fix crash
                //
                //      BEFORE [["id": 16, "position": 2], ["id": 11, "position": 3], ["id": 9, "position": 6], ["id": 2, "position": 8], ["id": 21, "position": 9], ["id": 15, "position": 11], ["id": 22, "position": 12], ["id": 5, "position": 13], ["id": 1, "position": 17], ["id": 18, "position": 22]]
                //      INSERTED AT index 1
                //      INSERTED AT index 2
                //      INSERTED AT index 3
                //      DELETED FROM index 1
                //      INSERTED AT index 4
                //      DELETED FROM index 3
                //      MOVED FROM index 0 TO index 6 WITH CHANGES: ["position": 1]
                //      MOVED FROM index 4 TO index 0 WITH CHANGES: ["position": 13]
                //      MOVED FROM index 2 TO index 7 WITH CHANGES: ["position": 6]
                //      INSERTED AT index 8
                //      DELETED FROM index 6
                //      INSERTED AT index 9
                //      DELETED FROM index 7
                //      INSERTED AT index 10
                //      UPDATED AT index 5 WITH CHANGES: ["position": 15]
                //      AFTER [["id": 21, "position": 1], ["id": 2, "position": 5], ["id": 20, "position": 6], ["id": 6, "position": 9], ["id": 23, "position": 10], ["id": 13, "position": 12], ["id": 10, "position": 15], ["id": 7, "position": 16], ["id": 1, "position": 18], ["id": 3, "position": 19], ["id": 4, "position": 21]]
                let cell = self.tableView.cellForRowAtIndexPath(indexPath)
                self.tableView.moveRowAtIndexPath(indexPath, toIndexPath: newIndexPath)
                if !changes.isEmpty, let cell = cell {
                    self.configureCell(cell, atIndexPath: newIndexPath)
                }
                
            case .Update(let indexPath, _):
                if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
                    self.configureCell(cell, atIndexPath: indexPath)
                }
            }
        }
        
        fetchedRecordsController.didChange { [unowned self] in
            // All events have been applied
            print("AFTER \(self.fetchedRecordsController.fetchedRecords!.map { ["id":$0.id, "position":$0.position] })")
            self.tableView.endUpdates()
        }
        
        // TODO: fix crash
        //
        // When we remove the comparison function below, the controller only
        // emits deletes and inserts.
        //
        // This should work just as well.
        //
        // But sometimes it crashes:
        //
        //      POSITIONS BEFORE [0, 4, 6, 7, 9, 12, 15, 16, 18, 19]
        //      INSERTED AT index 0
        //      INSERTED AT index 1
        //      DELETED FROM index 0
        //      INSERTED AT index 2
        //      DELETED FROM index 1
        //      INSERTED AT index 3
        //      DELETED FROM index 2
        //      INSERTED AT index 4
        //      DELETED FROM index 3
        //      INSERTED AT index 5
        //      DELETED FROM index 4
        //      INSERTED AT index 6
        //      DELETED FROM index 5
        //      INSERTED AT index 7
        //      DELETED FROM index 6
        //      INSERTED AT index 8
        //      DELETED FROM index 8
        //      DELETED FROM index 9
        //      INSERTED AT index 10
        //      DELETED FROM index 10
        //      INSERTED AT index 11
        //      POSITIONS AFTER [1, 2, 3, 6, 7, 10, 11, 13, 15, 17, 18, 19]
        //      endUpdates(): crash
        
        // Compare two persons. Returns true if controller should emit a .Move or
        // .Update event instead of a deletion/insertion.
        fetchedRecordsController.compare { (person1, person2) in
            person1.id == person2.id
        }
        
        fetchedRecordsController.performFetch()
    }

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
    }
    
    func swapNames() {
        let person = Person.filter(Col.visible).order(sql: "RANDOM()").fetchOne(dbQueue)!
        (person.lastName, person.firstName) = (person.firstName, person.lastName)
        try! person.save(dbQueue)
    }
    
    func shufflePersons() {
        try! dbQueue.inTransaction { (db) -> TransactionCompletion in
            var persons = Person.fetchAll(db)
            persons.shuffleInPlace()
            for (i, p) in persons.enumerate() {
                p.position = Int64(i)
                p.visible = (Int(arc4random_uniform(2)) == 0)
                try p.save(db)
            }
            return .Commit
        }
    }

    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showPerson" {
            let person = fetchedRecordsController.recordAtIndexPath(self.tableView.indexPathForSelectedRow!)
            let detailViewController = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
            detailViewController.person = person
            detailViewController.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
            detailViewController.navigationItem.leftItemsSupplementBackButton = true
        }
        else if segue.identifier == "editNewPerson" {
            let personEditionViewController = (segue.destinationViewController as! UINavigationController).topViewController as! PersonEditionViewController
            personEditionViewController.person = Person()
        }
    }
    
    // Unwind action: commit person edition
    @IBAction func commitPersonEdition(segue: UIStoryboardSegue) {
        let personEditionViewController = segue.sourceViewController as! PersonEditionViewController
        let person = personEditionViewController.person
        
        // Ignore person with no name
        guard (person.firstName ?? "").characters.count > 0 || (person.lastName ?? "").characters.count > 0 else {
            return
        }
        
        // Save person
        try! dbQueue.inDatabase { db in
            try person.save(db)
        }
    }
    
    
    // MARK: - Table View
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let persons = fetchedRecordsController.fetchedRecords {
            return persons.count
        }
        return 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    private func configureCell(cell: UITableViewCell, atIndexPath indexPath:NSIndexPath) {
        let person = fetchedRecordsController.recordAtIndexPath(indexPath)!
        cell.textLabel!.text = "\(person.position) - \(person.fullName)"
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        // Delete the person
        let person = fetchedRecordsController.recordAtIndexPath(indexPath)!
        try! dbQueue.inTransaction { db in
            try person.delete(db)
            return .Commit
        }
    }
}

extension MutableCollectionType where Index == Int {
    /// Shuffle the elements of `self` in-place.
    mutating func shuffleInPlace() {
        // empty and single-element collections don't shuffle
        if count < 2 { return }
        
        for i in 0..<count - 1 {
            let j = Int(arc4random_uniform(UInt32(count - i))) + i
            guard i != j else { continue }
            swap(&self[i], &self[j])
        }
    }
}
