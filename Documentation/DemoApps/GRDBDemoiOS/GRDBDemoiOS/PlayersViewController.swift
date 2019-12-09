import UIKit
import GRDB

/// PlayersViewController displays the list of players.
class PlayersViewController: UITableViewController {
    private enum PlayerOrdering {
        case byName
        case byScore
    }
    
    @IBOutlet private weak var newPlayerButtonItem: UIBarButtonItem!
    private var players: [Player] = []
    private var playersObserver: TransactionObserver?
    private var playerCountObserver: TransactionObserver?
    private var playerOrdering: PlayerOrdering = .byScore {
        didSet {
            configureOrderingBarButtonItem()
            configureTableView()
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
        configureNavigationItem()
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
    
    private func configureNavigationItem() {
        navigationItem.leftBarButtonItems = [editButtonItem, newPlayerButtonItem]
        configureOrderingBarButtonItem()
        configureTitle()
    }
    
    private func configureOrderingBarButtonItem() {
        switch playerOrdering {
        case .byScore:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Score ▼",
                style: .plain,
                target: self, action: #selector(sortByName))
        case .byName:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Name ▲",
                style: .plain,
                target: self, action: #selector(sortByScore))
        }
    }
    
    private func configureTitle() {
        // Track changes in the number of players
        let observation = ValueObservation.tracking { db in
            try Player.fetchCount(db)
        }
        playerCountObserver = observation.start(
            in: dbQueue,
            onError: { error in
                fatalError("Unexpected error: \(error)")
        },
            onChange: { [weak self] count in
                guard let self = self else { return }
                switch count {
                case 0: self.navigationItem.title = "No Player"
                case 1: self.navigationItem.title = "1 Player"
                default: self.navigationItem.title = "\(count) Players"
                }
        })
    }
    
    private func configureTableView() {
        // Track changes in the list of players
        let request = self.playersRequest
        let observation = ValueObservation.tracking { db in
            try request.fetchAll(db)
        }
        playersObserver = observation.start(
            in: dbQueue,
            onError: { error in
                fatalError("Unexpected error: \(error)")
        },
            onChange: { [weak self] players in
                guard let self = self else { return }
                
                // Compute difference between current and new list of players
                let difference = players
                    .difference(from: self.players)
                    .inferringMoves()
                
                // Apply those changes to the table view
                self.tableView.performBatchUpdates({
                    self.players = players
                    for change in difference {
                        switch change {
                        case let .remove(offset, _, associatedWith):
                            if let associatedWith = associatedWith {
                                self.tableView.moveRow(
                                    at: IndexPath(row: offset, section: 0),
                                    to: IndexPath(row: associatedWith, section: 0))
                            } else {
                                self.tableView.deleteRows(
                                    at: [IndexPath(row: offset, section: 0)],
                                    with: .fade)
                            }
                        case let .insert(offset, _, associatedWith):
                            if associatedWith == nil {
                                self.tableView.insertRows(
                                    at: [IndexPath(row: offset, section: 0)],
                                    with: .fade)
                            }
                        }
                    }
                }, completion: nil)
        })
    }
}


// MARK: - Navigation

extension PlayersViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Edit" {
            let player = players[tableView.indexPathForSelectedRow!.row]
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
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the player
        let player = players[indexPath.row]
        try! dbQueue.write { db in
            _ = try player.delete(db)
        }
    }
    
    private func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = players[indexPath.row]
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
