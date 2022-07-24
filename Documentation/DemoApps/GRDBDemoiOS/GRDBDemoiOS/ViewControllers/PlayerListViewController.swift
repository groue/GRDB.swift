import UIKit
import GRDB

/// PlayerListViewController displays the list of players.
class PlayerListViewController: UITableViewController {
    private enum PlayerOrdering {
        case byName
        case byScore
    }
    
    @IBOutlet private weak var newPlayerButtonItem: UIBarButtonItem!
    private var dataSource: PlayerDataSource!
    private var playersCancellable: DatabaseCancellable?
    private var playerOrdering: PlayerOrdering = .byScore {
        didSet {
            configureOrderingBarButtonItem()
            observePlayers()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureToolbar()
        configureNavigationItem()
        configureDataSource()
        observePlayers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
    
    private func configureToolbar() {
        toolbarItems = [
            UIBarButtonItem(systemItem: .trash, primaryAction: UIAction { [unowned self] _ in
                setEditing(false, animated: true)
                try! AppDatabase.shared.deleteAllPlayers()
            }),
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(systemItem: .refresh, primaryAction: UIAction { [unowned self] _ in
                setEditing(false, animated: true)
                try! AppDatabase.shared.refreshPlayers()
            }),
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(image: UIImage(systemName: "tornado"), primaryAction: UIAction { [unowned self] _ in
                setEditing(false, animated: true)
                for _ in 0..<50 {
                    DispatchQueue.global().async {
                        try! AppDatabase.shared.refreshPlayers()
                    }
                }
            }),
        ]
    }
    
    private func configureNavigationItem() {
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Players")
        navigationItem.leftBarButtonItems = [editButtonItem, newPlayerButtonItem]
        configureOrderingBarButtonItem()
    }
    
    private func configureOrderingBarButtonItem() {
        switch playerOrdering {
        case .byScore:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Score ▼",
                primaryAction: UIAction { [unowned self] _ in
                    setEditing(false, animated: true)
                    playerOrdering = .byName
                })
        case .byName:
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Name ▲",
                primaryAction: UIAction { [unowned self] _ in
                    setEditing(false, animated: true)
                    playerOrdering = .byScore
                })
        }
    }
    
    private func configureDataSource() {
        dataSource = PlayerDataSource(tableView: tableView) { (tableView, indexPath, player) in
            let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
            if player.name.isEmpty {
                cell.textLabel?.text = "(anonymous)"
            } else {
                cell.textLabel?.text = player.name
            }
            cell.detailTextLabel?.text = abs(player.score) > 1 ? "\(player.score) points" : "0 point"
            return cell
        }
        dataSource.defaultRowAnimation = .fade
        tableView.dataSource = dataSource
    }
    
    private func configureTitle(from players: [Player]) {
        switch players.count {
        case 0:
            navigationItem.title = "No Player"
        case 1:
            navigationItem.title = "1 Player"
        case let count:
            navigationItem.title = "\(count) Players"
        }
    }
    
    private func configureDataSource(from players: [Player]) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Player>()
        snapshot.appendSections([0])
        snapshot.appendItems(players, toSection: 0)
        
        // Remember selection
        let selectedPlayerId = tableView.indexPathForSelectedRow.flatMap {
            dataSource.itemIdentifier(for: $0)?.id
        }
        
        // Avoid a UIKit warning; don't animate when popping from edition
        let animated = view.window != nil
        
        dataSource.apply(snapshot, animatingDifferences: animated, completion: {
            // Restore selection
            if let index = players.firstIndex(where: { $0.id == selectedPlayerId }) {
                self.tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
            }
        })
    }
    
    private func observePlayers() {
        let request: QueryInterfaceRequest<Player>
        switch playerOrdering {
        case .byName:
            request = Player.all().orderedByName()
        case .byScore:
            request = Player.all().orderedByScore()
        }
        
        playersCancellable = ValueObservation
            .tracking(request.fetchAll(_:))
            .start(
                in: AppDatabase.shared.databaseReader,
                // Immediate scheduling feeds the data source right on subscription,
                // and avoids an undesired animation when the application starts.
                scheduling: .immediate,
                onError: { error in fatalError("Unexpected error: \(error)") },
                onChange: { [weak self] players in
                    guard let self else { return }
                    self.configureTitle(from: players)
                    self.configureDataSource(from: players)
                })
    }
}


// MARK: - Navigation

extension PlayerListViewController {
    @IBSegueAction func makePlayerEditionViewController(_ coder: NSCoder) -> PlayerEditionViewController? {
        guard let indexPath = tableView.indexPathForSelectedRow,
              let player = dataSource.itemIdentifier(for: indexPath)
        else { return nil }
        return PlayerEditionViewController(coder, mode: .edition, player: player)
    }
    
    @IBSegueAction func makePlayerCreationViewController(_ coder: NSCoder) -> PlayerEditionViewController? {
        let player = Player(id: nil, name: "", score: 0)
        return PlayerEditionViewController(coder, mode: .creation, player: player)
    }
    
    @IBAction func cancelPlayerEdition(_ segue: UIStoryboardSegue) {
        // Player creation cancelled
    }
    
    @IBAction func commitPlayerEdition(_ segue: UIStoryboardSegue) {
        // Player creation committed
    }
}


// MARK: - UITableViewDataSource

/// Subclass of UITableViewDiffableDataSource that supports row deletion
private class PlayerDataSource: UITableViewDiffableDataSource<Int, Player> {
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // Delete the player
        if let player = itemIdentifier(for: indexPath), let id = player.id {
            try! AppDatabase.shared.deletePlayers(ids: [id])
        }
    }
}
