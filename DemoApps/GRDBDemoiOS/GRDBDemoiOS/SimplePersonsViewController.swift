import UIKit
import GRDB

class SimplePersonsViewController: UITableViewController {
    var persons: [Person]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(SimplePersonsViewController.addPerson(_:))),
            editButtonItem
        ]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPersons()
        tableView.reloadData()
    }
    
    private func loadPersons() {
        persons = dbQueue.inDatabase { db in
            Person.order(Column("score").desc, Column("name")).fetchAll(db)
        }
    }
}


// MARK: - Navigation

extension SimplePersonsViewController : PersonEditionViewControllerDelegate {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditPerson" {
            let person = persons[tableView.indexPathForSelectedRow!.row]
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

extension SimplePersonsViewController {
    func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let person = persons[indexPath.row]
        cell.textLabel?.text = person.name
        cell.detailTextLabel?.text = abs(person.score) > 1 ? "\(person.score) points" : "0 point"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return persons.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Person", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the person
        let person = persons[indexPath.row]
        try! dbQueue.inDatabase { db in
            _ = try person.delete(db)
        }
        persons.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
    }
}
