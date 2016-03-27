import UIKit
import GRDB

class FetchedRecordsControllerDemoViewController: UITableViewController {
    var personsController: FetchedRecordsController<Person>!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(FetchedRecordsControllerDemoViewController.addPerson(_:))),
            editButtonItem()
        ]
        
        let request = FetchedRecordsControllerDemoViewController.personsSortedByScore
        personsController = FetchedRecordsController(dbQueue, request: request, compareRecordsByPrimaryKey: true)
        personsController.delegate = self
        personsController.performFetch()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        configureToolbar()
    }
}


// MARK: - Navigation

extension FetchedRecordsControllerDemoViewController : PersonEditionViewControllerDelegate {
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "EditPerson" {
            let person = personsController.recordAtIndexPath(tableView.indexPathForSelectedRow!)
            let controller = segue.destinationViewController as! PersonEditionViewController
            controller.title = person.name
            controller.person = person
            controller.delegate = self // we will save person when back button is tapped
            controller.cancelButtonHidden = true
            controller.commitButtonHidden = true
        }
        else if segue.identifier == "NewPerson" {
            setEditing(false, animated: true)
            let navigationController = segue.destinationViewController as! UINavigationController
            let controller = navigationController.viewControllers.first as! PersonEditionViewController
            controller.title = NSLocalizedString("New Person", comment: "")
            controller.person = Person(name: "", score: 0)
        }
    }
    
    @IBAction func addPerson(sender: AnyObject?) {
        performSegueWithIdentifier("NewPerson", sender: sender)
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

extension FetchedRecordsControllerDemoViewController {
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let person = personsController.recordAtIndexPath(indexPath)
        cell.textLabel?.text = person.name
        cell.detailTextLabel?.text = abs(person.score) > 1 ? "\(person.score) points" : "0 point"
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
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        // Delete the person
        let person = personsController.recordAtIndexPath(indexPath)
        try! person.delete(dbQueue)
    }
}


// MARK: - FetchedRecordsControllerDelegate

extension FetchedRecordsControllerDemoViewController : FetchedRecordsControllerDelegate {
    
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
            // Actually move cells around for more demo effect :-)
            let cell = tableView.cellForRowAtIndexPath(indexPath)
            tableView.moveRowAtIndexPath(indexPath, toIndexPath: newIndexPath)
            if let cell = cell {
                configureCell(cell, atIndexPath: newIndexPath)
            }
            
            // A quieter animation:
            // tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            // tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeRecords<T>(controller: FetchedRecordsController<T>) {
        tableView.endUpdates()
    }
}


// MARK: - FetchedRecordsController Demo

extension FetchedRecordsControllerDemoViewController {
    
    private static let personsSortedByName = Person.order(SQLColumn("name"))
    private static let personsSortedByScore = Person.order(SQLColumn("score").desc, SQLColumn("name"))
    
    private func configureToolbar() {
        navigationController?.toolbarHidden = false
        toolbarItems = [
            UIBarButtonItem(
                title: NSLocalizedString("Name ⬆︎", comment: ""),
                style: .Plain,
                target: self,
                action: #selector(FetchedRecordsControllerDemoViewController.sortByName)),
            UIBarButtonItem(
                title: NSLocalizedString("Score ⬇︎", comment: ""),
                style: .Plain,
                target: self,
                action: #selector(FetchedRecordsControllerDemoViewController.sortByScore)),
            UIBarButtonItem(
                title: NSLocalizedString("Randomize", comment: ""),
                style: .Plain,
                target: self,
                action: #selector(FetchedRecordsControllerDemoViewController.randomizeScores)),
            UIBarButtonItem(
                barButtonSystemItem: .FlexibleSpace,
                target: nil,
                action: nil),
            UIBarButtonItem(
                title: NSLocalizedString("💣", comment: ""),
                style: .Plain,
                target: self,
                action: #selector(FetchedRecordsControllerDemoViewController.stress))
        ]
    }
    
    @IBAction func sortByName() {
        personsController.setRequest(FetchedRecordsControllerDemoViewController.personsSortedByName)
    }
    
    @IBAction func sortByScore() {
        personsController.setRequest(FetchedRecordsControllerDemoViewController.personsSortedByScore)
    }
    
    @IBAction func randomizeScores() {
        try! dbQueue.inTransaction { db in
            for person in Person.fetch(db) {
                person.score = randomScore()
                try person.update(db)
            }
            return .Commit
        }
    }
    
    @IBAction func stress() {
        // Spawn some concurrent background jobs
        for _ in 0...Int(arc4random_uniform(20)) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                try! dbQueue.inTransaction { db in
                    // Insert a person
                    if arc4random_uniform(2) == 0 {
                        let person = Person(name: randomName(), score: randomScore())
                        try person.insert(db)
                    }
                    // Delete a person
                    if arc4random_uniform(2) == 0 {
                        if let person = Person.order(sql: "RANDOM()").fetchOne(db) {
                            try person.delete(db)
                        }
                    }
                    // Update some persons
                    for person in Person.fetchAll(db) {
                        if arc4random_uniform(4) == 0 {
                            person.score = randomScore()
                            try person.update(db)
                        }
                    }
                    return .Commit
                }
            }
        }
    }
}
