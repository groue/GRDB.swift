import UIKit

class PlayerEditionViewController: UITableViewController {
    enum Presentation {
        /// Modal presentation: edition ends with the "Commit" segue.
        case modal
        
        /// Push presentation: edition ends when user hits the back button.
        case push
    }
    
    var player: Player! { didSet { configureView() } }
    var presentation: Presentation! { didSet { configureView() } }

    @IBOutlet fileprivate weak var cancelBarButtonItem: UIBarButtonItem!
    @IBOutlet fileprivate weak var commitBarButtonItem: UIBarButtonItem!
    @IBOutlet fileprivate weak var nameCell: UITableViewCell!
    @IBOutlet fileprivate weak var nameTextField: UITextField!
    @IBOutlet fileprivate weak var scoreCell: UITableViewCell!
    @IBOutlet fileprivate weak var scoreTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }
    
    fileprivate func configureView() {
        guard isViewLoaded else { return }
        
        nameTextField.text = player.name
        
        if player.score == 0 && player.id == nil {
            scoreTextField.text = ""
        } else {
            scoreTextField.text = "\(player.score)"
        }
        
        switch presentation! {
        case .modal:
            navigationItem.leftBarButtonItem = cancelBarButtonItem
            navigationItem.rightBarButtonItem = commitBarButtonItem
        case .push:
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil
        }
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
        
        switch presentation! {
        case .modal:
            break
        case .push:
            if parent == nil {
                // Self is popping from its navigation controller
                saveChanges()
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
    
    private func saveChanges() {
        guard var player = self.player else {
            return
        }
        player.name = nameTextField.text ?? ""
        player.score = scoreTextField.text.flatMap { Int($0) } ?? 0
        self.player = player
        
        try! dbQueue.inDatabase { db in
            try player.save(db)
        }
    }
}
