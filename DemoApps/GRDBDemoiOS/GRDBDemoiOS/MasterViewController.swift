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
            UIBarButtonItem(title: "Swap Names", style: UIBarButtonItemStyle.Done, target: self, action: #selector(MasterViewController.swapNames)),
            UIBarButtonItem(title: "Shuffle", style: UIBarButtonItemStyle.Done, target: self, action: #selector(MasterViewController.shufflePersons)),
            UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        ]
        self.navigationController?.toolbarHidden = false
        
        // The fetched objects
        let fetchRequest = Person.filter(Col.visible).order(Col.position, Col.firstName, Col.lastName)
        fetchedRecordsController = FetchedRecordsController(dbQueue, fetchRequest, isSameRecord: { (person1, person2) in
            person1.id == person2.id
        })
        
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
//                self.tableView.deleteRowsAtIndexPaths([indexPath],
//                    withRowAnimation: UITableViewRowAnimation.Fade)
//                self.tableView.insertRowsAtIndexPaths([newIndexPath],
//                    withRowAnimation: UITableViewRowAnimation.Fade)
                
                // Technique 2 (move & update)
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
        try! dbQueue.inTransaction { db in
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
        try! person.save(dbQueue)
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
        try! person.delete(dbQueue)
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
