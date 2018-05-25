import UIKit
import GRDB

class PlayersViewController: UITableViewController {
    var playersController: FetchedRecordsController<Player>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: .addPlayer),
            editButtonItem
        ]
        
        playersController = try! FetchedRecordsController(dbQueue, request: playersSortedByScore)
        playersController.trackChanges(
            willChange: { [unowned self] _ in
                self.tableView.beginUpdates()
            },
            onChange: { [unowned self] (controller, record, change) in
                switch change {
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
            didChange: { [unowned self] _ in
                self.tableView.endUpdates()
            })
        try! playersController.performFetch()
        
        configureToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
}


// MARK: - Navigation

extension PlayersViewController : PlayerEditionViewControllerDelegate {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditPlayer" {
            let player = playersController.record(at: tableView.indexPathForSelectedRow!)
            let controller = segue.destination as! PlayerEditionViewController
            controller.title = player.name
            controller.player = player
            controller.delegate = self // we will save player when back button is tapped
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

extension PlayersViewController {
    func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = playersController.record(at: indexPath)
        cell.textLabel?.text = player.name
        cell.detailTextLabel?.text = abs(player.score) > 1 ? "\(player.score) points" : "0 point"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return playersController.sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playersController.sections[section].numberOfRecords
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the player
        let player = playersController.record(at: indexPath)
        try! dbQueue.write { db in
            _ = try player.delete(db)
        }
    }
}


// MARK: - FetchedRecordsController Demo

extension PlayersViewController {
    
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
        try! playersController.setRequest(playersSortedByName)
    }
    
    @IBAction func sortByScore() {
        setEditing(false, animated: true)
        try! playersController.setRequest(playersSortedByScore)
    }
    
    @IBAction func randomizeScores() {
        setEditing(false, animated: true)
        
        try! dbQueue.write { db in
            for var player in try Player.fetchAll(db) {
                player.score = Player.randomScore()
                try player.update(db)
            }
        }
    }
    
    @IBAction func stressTest() {
        setEditing(false, animated: true)
        
        for _ in 0..<50 {
            DispatchQueue.global().async {
                try! dbQueue.write { db in
                    if try Player.fetchCount(db) == 0 {
                        // Insert players
                        for _ in 0..<8 {
                            var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                            try player.insert(db)
                        }
                    } else {
                        // Insert a player
                        if arc4random_uniform(2) == 0 {
                            var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                            try player.insert(db)
                        }
                        // Delete a player
                        if arc4random_uniform(2) == 0 {
                            if let player = try Player.order(sql: "RANDOM()").fetchOne(db) {
                                try player.delete(db)
                            }
                        }
                        // Update some players
                        for var player in try Player.fetchAll(db) {
                            if arc4random_uniform(2) == 0 {
                                player.score = Player.randomScore()
                                try player.update(db)
                            }
                        }
                    }
                }
            }
        }
    }
}

// https://medium.com/swift-programming/swift-selector-syntax-sugar-81c8a8b10df3
private extension Selector {
    static let addPlayer       = #selector(PlayersViewController.addPlayer(_:))
    static let sortByName      = #selector(PlayersViewController.sortByName)
    static let sortByScore     = #selector(PlayersViewController.sortByScore)
    static let randomizeScores = #selector(PlayersViewController.randomizeScores)
    static let stressTest      = #selector(PlayersViewController.stressTest)
}

private let playersSortedByName = Player.order(Column("name"))
private let playersSortedByScore = Player.order(Column("score").desc, Column("name"))
