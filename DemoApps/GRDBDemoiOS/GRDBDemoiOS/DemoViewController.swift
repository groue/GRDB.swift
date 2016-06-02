import UIKit

class DemoViewController: UITableViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        navigationController?.isToolbarHidden = true
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Demo", style: .plain, target: nil, action: nil)
    }
}
