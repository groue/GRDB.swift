import UIKit

class PlayerEditionViewController: UITableViewController {
    enum Presentation {
        /// Modal presentation: edition ends with the "Commit" unwind segue.
        case modal
        
        /// Push presentation: edition ends when user hits the back button.
        case push
    }
    
    /// The edited player
    var player: Player! {
        didSet {
            configureForm()
        }
    }
    
    /// The presentation mode
    var presentation: Presentation! {
        didSet {
            configureNavigationItem()
        }
    }
    
    @IBOutlet private weak var cancelBarButtonItem: UIBarButtonItem!
    @IBOutlet private weak var commitBarButtonItem: UIBarButtonItem!
    @IBOutlet private weak var nameCell: UITableViewCell!
    @IBOutlet private weak var nameTextField: UITextField!
    @IBOutlet private weak var scoreCell: UITableViewCell!
    @IBOutlet private weak var scoreTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureForm()
        configureNavigationItem()
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
        
        if case .push = presentation, parent == nil {
            // Self is popping from its navigation controller
            saveChanges()
        }
    }
    
    private func configureNavigationItem() {
        guard isViewLoaded else { return }
        
        if let presentation = presentation {
            switch presentation {
            case .modal:
                navigationItem.leftBarButtonItem = cancelBarButtonItem
                navigationItem.rightBarButtonItem = commitBarButtonItem
            case .push:
                navigationItem.leftBarButtonItem = nil
                navigationItem.rightBarButtonItem = nil
            }
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
        if case .modal = presentation {
            isModalInPresentation = true
        }
    }
    
    private func configureForm() {
        guard isViewLoaded else { return }
        
        nameTextField.text = player.name
        
        if player.score == 0 && player.id == nil {
            scoreTextField.text = ""
        } else {
            scoreTextField.text = "\(player.score)"
        }
    }
    
    private func saveChanges() {
        guard var player = self.player else {
            return
        }
        player.name = nameTextField.text ?? ""
        player.score = scoreTextField.text.flatMap { Int($0) } ?? 0
        try! AppDatabase.shared.savePlayer(&player)
        self.player = player
    }
}
