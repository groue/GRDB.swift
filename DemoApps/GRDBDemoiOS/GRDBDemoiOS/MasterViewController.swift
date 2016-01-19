import UIKit
import GRDB

class MasterViewController: UITableViewController, FetchedResultsControllerDelegate {
    var detailViewController: DetailViewController? = nil
    var fetchedResultsController: FetchedResultsController<Person>!
    var persons = [Person]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = self.editButtonItem()
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        fetchedResultsController = FetchedResultsController(sql: "SELECT * FROM persons ORDER BY LOWER(firstName), LOWER(lastName)", databaseQueue: dbQueue)
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch()
        tableView.reloadData()
    }

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
    }
    
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showPerson" {
            let person = fetchedResultsController.recordAtIndexPath(self.tableView.indexPathForSelectedRow!)
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
        if let persons = fetchedResultsController.fetchedResults {
            return persons.count
        }
        return 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        let person = fetchedResultsController.recordAtIndexPath(indexPath)!
        cell.textLabel!.text = person.fullName
        return cell
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        // Delete the person
        let person = fetchedResultsController.recordAtIndexPath(indexPath)!
        try! dbQueue.inTransaction { db in
            try person.delete(db)
            return .Commit
        }
    }
    
    // MARK: - FetchedResultsControllerDelegate
    
    func controllerWillUpdate<T>(controller: FetchedResultsController<T>) {
        tableView.beginUpdates()
    }
    
    func controllerUpdate<T>(controller: FetchedResultsController<T>, update: Update<T>) {
        switch update {
        case .Insertion(_, let at):
            tableView.insertRowsAtIndexPaths([at], withRowAnimation: .Automatic)
            
        case .Deletion(_, let from):
            tableView.deleteRowsAtIndexPaths([from], withRowAnimation: .Automatic)
            
        case .Move(_, let from, let to):
            tableView.moveRowAtIndexPath(from, toIndexPath: to)
            
        case .Update(_, let at, let changes):
            if let changes = changes {
                let columns = ["firstName", "lastName"]
                for (key, _) in changes {
                    if columns.contains(key) {
                        tableView.reloadRowsAtIndexPaths([at], withRowAnimation: .Automatic)
                        break
                    }
                }
            } else {
                tableView.reloadRowsAtIndexPaths([at], withRowAnimation: .Automatic)
            }
        }
    }
    
    func controllerDidFinishUpdates<T>(controller: FetchedResultsController<T>) {
        tableView.endUpdates()
    }
}

