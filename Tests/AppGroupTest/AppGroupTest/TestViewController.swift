import UIKit

class TestViewController: UIViewController {
    var test: Test!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var instructionsLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        titleLabel.text = test.title
        instructionsLabel.text = test.instructions
        try! test.enter()
    }
    
    @IBAction func done(_ sender: Any?) {
        try! test.leave()
    }
}
