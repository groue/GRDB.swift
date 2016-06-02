import UIKit

class PersonEditionViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet weak var firstNameTableViewCell: UITableViewCell!
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTableViewCell: UITableViewCell!
    @IBOutlet weak var lastNameTextField: UITextField!
    
    // The edited person
    var person: Person!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initializes textFields with the person's names
        firstNameTextField.text = person.firstName
        lastNameTextField.text = person.lastName
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Auto focus firstName
        firstNameTextField.becomeFirstResponder()
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // Tapping a cell selects its text fields.
        if indexPath == tableView.indexPathForCell(firstNameTableViewCell) {
            firstNameTextField.becomeFirstResponder()
        } else if indexPath == tableView.indexPathForCell(lastNameTableViewCell) {
            lastNameTextField.becomeFirstResponder()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Tapping Return key focuses next text field.
        if textField == firstNameTextField {
            lastNameTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        // Update person when text field ends editing.
        if textField == firstNameTextField {
            person.firstName = textField.text
        } else if textField == lastNameTextField {
            person.lastName = textField.text
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // About to cancel or commit: end editing.
        // This dismisses the keyboard early, and apply pending changes through
        // textFieldDidEndEditing(_).
        view.endEditing(true)
    }
}
