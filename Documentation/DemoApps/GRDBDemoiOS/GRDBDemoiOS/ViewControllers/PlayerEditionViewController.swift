import UIKit

class PlayerEditionViewController: UITableViewController {
    enum Mode {
        /// Edition ends with the "Commit" unwind segue.
        case creation
        
        /// Edition ends when user hits the back button.
        case edition
    }
    
    /// The edited player
    private(set) var player: Player
    
    /// The presentation mode
    let mode: Mode
    
    @IBOutlet private weak var cancelButtonItem: UIBarButtonItem!
    @IBOutlet private weak var saveButtonItem: UIBarButtonItem!
    @IBOutlet private weak var nameCell: UITableViewCell!
    @IBOutlet private weak var nameTextField: UITextField!
    @IBOutlet private weak var scoreCell: UITableViewCell!
    @IBOutlet private weak var scoreTextField: UITextField!
    
    init?(_ coder: NSCoder, mode: Mode, player: Player) {
        self.mode = mode
        self.player = player
        super.init(coder: coder)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
        configureForm()
    }
}

// MARK: - Navigation

extension PlayerEditionViewController {
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // Force keyboard to dismiss early
        view.endEditing(true)
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Commit" {
            saveChanges()
        }
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        
        if mode == .edition, parent == nil {
            // Self is popping from its navigation controller
            saveChanges()
        }
    }
    
    private func configureNavigationItem() {
        switch mode {
        case .creation:
            navigationItem.title = "New Player"
            navigationItem.leftBarButtonItem = cancelButtonItem
            navigationItem.rightBarButtonItem = saveButtonItem
        case .edition:
            navigationItem.title = player.name
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil
        }
    }
}

// MARK: - Form

extension PlayerEditionViewController: UITextFieldDelegate {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        nameTextField.becomeFirstResponder()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let cell = tableView.cellForRow(at: indexPath)
        if cell === nameCell {
            nameTextField.becomeFirstResponder()
        } else if cell === scoreCell {
            scoreTextField.becomeFirstResponder()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameTextField {
            scoreTextField.becomeFirstResponder()
        }
        return false
    }
    
    @IBAction func textFieldDidChange(_ textField: UITextField) {
        // User has edited the player: prevent interactive dismissal
        isModalInPresentation = true
    }
    
    private func configureForm() {
        nameTextField.text = player.name
        
        if player.score == 0 && player.id == nil {
            scoreTextField.text = ""
        } else {
            scoreTextField.text = "\(player.score)"
        }
    }
    
    private func saveChanges() {
        var player = self.player
        player.name = nameTextField.text ?? ""
        player.score = scoreTextField.text.flatMap { Int($0) } ?? 0
        try! AppDatabase.shared.savePlayer(&player)
        self.player = player
    }
}
