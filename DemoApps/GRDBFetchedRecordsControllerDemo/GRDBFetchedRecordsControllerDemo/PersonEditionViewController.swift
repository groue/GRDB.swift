import UIKit

protocol PersonEditionViewControllerDelegate: class {
    func personEditionControllerDidComplete(controller: PersonEditionViewController)
}

class PersonEditionViewController: UITableViewController {
    weak var delegate: PersonEditionViewControllerDelegate?
    var person: Person! { didSet { configureView() } }
    var cancelButtonHidden: Bool = false { didSet { configureView() } }
    var commitButtonHidden: Bool = false { didSet { configureView() } }

    @IBOutlet private weak var cancelBarButtonItem: UIBarButtonItem!
    @IBOutlet private weak var commitBarButtonItem: UIBarButtonItem!
    @IBOutlet private weak var nameTextField: UITextField!
    @IBOutlet private weak var scoreTextField: UITextField!
    
    func applyChanges() {
        person.name = nameTextField.text ?? ""
        person.score = scoreTextField.text.flatMap { Int($0) } ?? 0
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        configureView()
        nameTextField.becomeFirstResponder()
    }
    
    override func willMoveToParentViewController(parent: UIViewController?) {
        super.willMoveToParentViewController(parent)
        
        if parent == nil {
            // Self is popping from its navigation controller
            delegate?.personEditionControllerDidComplete(self)
        }
    }
    
    private func configureView() {
        guard isViewLoaded() else { return }
        
        nameTextField.text = person.name
        scoreTextField.text = "\(person.score)"
    
        if cancelButtonHidden {
            navigationItem.leftBarButtonItem = nil
        } else {
            navigationItem.leftBarButtonItem = cancelBarButtonItem
        }

        if cancelButtonHidden {
            navigationItem.rightBarButtonItem = nil
        } else {
            navigationItem.rightBarButtonItem = commitBarButtonItem
        }
    }
}
