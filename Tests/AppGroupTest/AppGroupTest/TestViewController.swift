import UIKit

class TestViewController: UIViewController {
    var step: (Int, Test)? = Tests.shared.next()
    @IBOutlet private weak var indexLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var instructionsLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.hidesBackButton = true
        if let (index, test) = step {
            navigationItem.title = "\(index + 1)"
            titleLabel.text = test.title
            instructionsLabel.text = test.instructions
            try! test.enter()
        } else {
            navigationItem.title = NSLocalizedString("End", comment: "")
            titleLabel.text = NSLocalizedString("Thank you!", comment: "")
            instructionsLabel.text = NSLocalizedString("Tests are completed.", comment: "")
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        leave()
        return false
    }
    
    private func leave() {
        guard let (_, test) = step else { return }
        test.leave { error in
            DispatchQueue.main.async {
                if let error = error {
                    let alert = UIAlertController(
                        title: NSLocalizedString("Error", comment: ""),
                        message: error.localizedDescription,
                        preferredStyle: .alert)
                    alert.addAction(.init(
                        title: NSLocalizedString("Quit", comment: ""),
                        style: .destructive,
                        handler: { _ in exit(1) }))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    self.performSegue(withIdentifier: "next", sender: self)
                }
            }
        }
    }
}
