import UIKit
import GRDB

class PersonsViewController: UITableViewController {
    var personsController: FetchedRecordsController<Person>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: .addPerson),
            editButtonItem
        ]
        
        let request = personsSortedByScore
        personsController = FetchedRecordsController(dbQueue, request: request, compareRecordsByPrimaryKey: true)
        personsController.trackChanges(
            recordsWillChange: { [unowned self] _ in
                self.tableView.beginUpdates()
            },
            tableViewEvent: { [unowned self] (controller, record, event) in
                switch event {
                case .insertion(let indexPath):
                    self.tableView.insertRows(at: [indexPath], with: .fade)
                    
                case .deletion(let indexPath):
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    
                case .update(let indexPath, _):
                    if let cell = self.tableView.cellForRow(at: indexPath) {
                        self.configure(cell, at: indexPath)
                    }
                    
                case .move(let indexPath, let newIndexPath, _):
                    // Actually move cells around for more demo effect :-)
                    let cell = self.tableView.cellForRow(at: indexPath)
                    self.tableView.moveRow(at: indexPath, to: newIndexPath)
                    if let cell = cell {
                        self.configure(cell, at: newIndexPath)
                    }
                    
                    // A quieter animation:
                    // self.tableView.deleteRows(at: [indexPath], with: .fade)
                    // self.tableView.insertRows(at: [newIndexPath], with: .fade)
                }
            },
            recordsDidChange: { [unowned self] _ in
                self.tableView.endUpdates()
            })
        personsController.performFetch()
        
        configureToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
}


// MARK: - Navigation

extension PersonsViewController : PersonEditionViewControllerDelegate {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditPerson" {
            let person = personsController.record(at: tableView.indexPathForSelectedRow!)
            let controller = segue.destination as! PersonEditionViewController
            controller.title = person.name
            controller.person = person
            controller.delegate = self // we will save person when back button is tapped
            controller.cancelButtonHidden = true
            controller.commitButtonHidden = true
        }
        else if segue.identifier == "NewPerson" {
            setEditing(false, animated: true)
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.viewControllers.first as! PersonEditionViewController
            controller.title = "New Person"
            controller.person = Person(name: "", score: 0)
        }
    }
    
    @IBAction func addPerson(_ sender: AnyObject?) {
        performSegue(withIdentifier: "NewPerson", sender: sender)
    }
    
    @IBAction func cancelPersonEdition(_ segue: UIStoryboardSegue) {
        // Person creation: cancel button was tapped
    }
    
    @IBAction func commitPersonEdition(_ segue: UIStoryboardSegue) {
        // Person creation: commit button was tapped
        let controller = segue.source as! PersonEditionViewController
        controller.applyChanges()
        let person = controller.person!
        if !person.name.isEmpty {
            try! dbQueue.inDatabase { db in
                try person.save(db)
            }
        }
    }
    
    func personEditionControllerDidComplete(_ controller: PersonEditionViewController) {
        // Person edition: back button was tapped
        controller.applyChanges()
        let person = controller.person!
        if !person.name.isEmpty {
            try! dbQueue.inDatabase { db in
                try person.save(db)
            }
        }
    }
}


// MARK: - UITableViewDataSource

extension PersonsViewController {
    func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let person = personsController.record(at: indexPath)
        cell.textLabel?.text = person.name
        cell.detailTextLabel?.text = abs(person.score) > 1 ? "\(person.score) points" : "0 point"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return personsController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return personsController.sections[section].numberOfRecords
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Person", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the person
        let person = personsController.record(at: indexPath)
        try! dbQueue.inDatabase { db in
            _ = try person.delete(db)
        }
    }
}


// MARK: - FetchedRecordsController Demo

extension PersonsViewController {
    
    fileprivate func configureToolbar() {
        toolbarItems = [
            UIBarButtonItem(title: "Name ⬆︎", style: .plain, target: self, action: .sortByName),
            UIBarButtonItem(title: "Score ⬇︎", style: .plain, target: self, action: .sortByScore),
            UIBarButtonItem(title: "Randomize", style: .plain, target: self, action: .randomizeScores),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: .stressTest)
        ]
    }
    
    @IBAction func sortByName() {
        setEditing(false, animated: true)
        personsController.setRequest(personsSortedByName)
    }
    
    @IBAction func sortByScore() {
        setEditing(false, animated: true)
        personsController.setRequest(personsSortedByScore)
    }
    
    @IBAction func randomizeScores() {
        setEditing(false, animated: true)
        
        try! dbQueue.inTransaction { db in
            for person in Person.fetch(db) {
                person.score = Person.randomScore()
                try person.update(db)
            }
            return .commit
        }
    }
    
    @IBAction func stressTest() {
        setEditing(false, animated: true)
        
        for _ in 0..<50 {
            DispatchQueue.global().async {
                try! dbQueue.inTransaction { db in
                    if Person.fetchCount(db) == 0 {
                        // Insert persons
                        for _ in 0..<8 {
                            try Person(name: Person.randomName(), score: Person.randomScore()).insert(db)
                        }
                    } else {
                        // Insert a person
                        if arc4random_uniform(2) == 0 {
                            let person = Person(name: Person.randomName(), score: Person.randomScore())
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
                            if arc4random_uniform(2) == 0 {
                                person.score = Person.randomScore()
                                try person.update(db)
                            }
                        }
                    }
                    return .commit
                }
            }
        }
    }
}

// https://medium.com/swift-programming/swift-selector-syntax-sugar-81c8a8b10df3
private extension Selector {
    static let addPerson       = #selector(PersonsViewController.addPerson(_:))
    static let sortByName      = #selector(PersonsViewController.sortByName)
    static let sortByScore     = #selector(PersonsViewController.sortByScore)
    static let randomizeScores = #selector(PersonsViewController.randomizeScores)
    static let stressTest      = #selector(PersonsViewController.stressTest)
}

private let personsSortedByName = Person.order(Column("name"))
private let personsSortedByScore = Person.order(Column("score").desc, Column("name"))
