import UIKit
import GRDB

class SimplePlayersViewController: UITableViewController {
    var players: [Player]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(SimplePlayersViewController.addPlayer(_:))),
            editButtonItem
        ]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        players = try! dbQueue.read { db in
            try Player.order(Column("score").desc, Column("name")).fetchAll(db)
        }
        tableView.reloadData()
    }
}


// MARK: - Navigation

extension SimplePlayersViewController : PlayerEditionViewControllerDelegate {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditPlayer" {
            let player = players[tableView.indexPathForSelectedRow!.row]
            let controller = segue.destination as! PlayerEditionViewController
            controller.title = player.name
            controller.player = player
            controller.delegate = self // see playerEditionControllerDidComplete
            controller.commitButtonHidden = true
        }
        else if segue.identifier == "NewPlayer" {
            setEditing(false, animated: true)
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.viewControllers.first as! PlayerEditionViewController
            controller.title = "New Player"
            controller.player = Player(id: nil, name: "", score: 0)
        }
    }
    
    @IBAction func addPlayer(_ sender: AnyObject?) {
        performSegue(withIdentifier: "NewPlayer", sender: sender)
    }
    
    @IBAction func cancelPlayerEdition(_ segue: UIStoryboardSegue) {
        // Player creation: cancel button was tapped
    }
    
    @IBAction func commitPlayerEdition(_ segue: UIStoryboardSegue) {
        // Player creation: commit button was tapped
        let controller = segue.source as! PlayerEditionViewController
        commitPlayerEdition(from: controller)
    }
    
    func playerEditionControllerDidComplete(_ controller: PlayerEditionViewController) {
        // Player edition: back button was tapped
        commitPlayerEdition(from: controller)
    }
    
    private func commitPlayerEdition(from controller: PlayerEditionViewController) {
        controller.applyChanges()
        var player = controller.player!
        if !player.name.isEmpty {
            try! dbQueue.write { db in
                try player.save(db)
            }
        }
    }
}


// MARK: - UITableViewDataSource

extension SimplePlayersViewController {
    func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = players[indexPath.row]
        cell.textLabel?.text = player.name
        cell.detailTextLabel?.text = abs(player.score) > 1 ? "\(player.score) points" : "0 point"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the player
        let player = players[indexPath.row]
        try! dbQueue.write { db in
            _ = try player.delete(db)
        }
        players.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
    }
}
