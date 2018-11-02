import UIKit
import GRDB

/// PlayersViewController displays the list of players.
class PlayersViewController: UITableViewController {
    private enum PlayerOrdering {
        case byName
        case byScore
    }
    
    @IBOutlet private weak var newPlayerButtonItem: UIBarButtonItem!
    private var playersController: FetchedRecordsController<Player>!
    private var playerCountObserver: TransactionObserver?
    private var playerOrdering: PlayerOrdering = .byScore {
        didSet {
            try! playersController.setRequest(playersRequest)
            configureOrderingBarButtonItem()
        }
    }
    private var playersRequest: QueryInterfaceRequest<Player> {
        switch playerOrdering {
        case .byName:
            return Player.orderedByName()
        case .byScore:
            return Player.orderedByScore()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureToolbar()
        configureOrderingBarButtonItem()
        configureTitle()
        configureTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
    
    private func configureToolbar() {
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePlayers)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(stressTest)),
        ]
    }
    
    private func configureOrderingBarButtonItem() {
        navigationItem.leftBarButtonItems = [editButtonItem, newPlayerButtonItem]
        
        switch playerOrdering {
        case .byScore:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Score ⬇︎",
                style: .plain,
                target: self, action: #selector(sortByName))
        case .byName:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Name ⬆︎",
                style: .plain,
                target: self, action: #selector(sortByScore))
        }
    }
    
    private func configureTitle() {
        // Track changes in the number of players
        playerCountObserver = try! ValueObservation
            .trackingCount(playersRequest)
            .start(in: dbQueue) { [unowned self] count in
                switch count {
                case 0: self.navigationItem.title = "No Player"
                case 1: self.navigationItem.title = "1 Player"
                default: self.navigationItem.title = "\(count) Players"
                }
        }
    }
    
    private func configureTableView() {
        // Track changes in the database players
        playersController = try! FetchedRecordsController(dbQueue, request: playersRequest)
        
        // Animate changes in the table view
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
        
        // Initial fetch
        try! playersController.performFetch()
    }
}


// MARK: - Navigation

extension PlayersViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Edit" {
            let player = playersController.record(at: tableView.indexPathForSelectedRow!)
            let controller = segue.destination as! PlayerEditionViewController
            controller.title = player.name
            controller.player = player
            controller.presentation = .push
        }
        else if segue.identifier == "New" {
            setEditing(false, animated: true)
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.viewControllers.first as! PlayerEditionViewController
            controller.title = "New Player"
            controller.player = Player(id: nil, name: "", score: 0)
            controller.presentation = .modal
        }
    }
    
    @IBAction func cancelPlayerEdition(_ segue: UIStoryboardSegue) {
        // Player creation cancelled
    }
    
    @IBAction func commitPlayerEdition(_ segue: UIStoryboardSegue) {
        // Player creation committed
    }
}


// MARK: - UITableViewDataSource

extension PlayersViewController {
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
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the player
        let player = playersController.record(at: indexPath)
        try! dbQueue.write { db in
            _ = try player.delete(db)
        }
    }
    
    private func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = playersController.record(at: indexPath)
        if player.name.isEmpty {
            cell.textLabel?.text = "-"
        } else {
            cell.textLabel?.text = player.name
        }
        cell.detailTextLabel?.text = abs(player.score) > 1 ? "\(player.score) points" : "0 point"
    }
}


// MARK: - Actions

extension PlayersViewController {
    @IBAction func sortByName() {
        setEditing(false, animated: true)
        playerOrdering = .byName
    }
    
    @IBAction func sortByScore() {
        setEditing(false, animated: true)
        playerOrdering = .byScore
    }
    
    @IBAction func deletePlayers() {
        setEditing(false, animated: true)
        try! dbQueue.write { db in
            _ = try Player.deleteAll(db)
        }
    }
    
    @IBAction func refresh() {
        setEditing(false, animated: true)
        refreshPlayers()
    }
    
    @IBAction func stressTest() {
        setEditing(false, animated: true)
        for _ in 0..<50 {
            DispatchQueue.global().async {
                self.refreshPlayers()
            }
        }
    }
    
    private func refreshPlayers() {
        try! dbQueue.write { db in
            if try Player.fetchCount(db) == 0 {
                // Insert new random players
                for _ in 0..<8 {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
            } else {
                // Insert a player
                if Bool.random() {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
                // Delete a random player
                if Bool.random() {
                    try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some players
                for var player in try Player.fetchAll(db) where Bool.random() {
                    player.score = Player.randomScore()
                    try player.update(db)
                }
            }
        }
    }
}
