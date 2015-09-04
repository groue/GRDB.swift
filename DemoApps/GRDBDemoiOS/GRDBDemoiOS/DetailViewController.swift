import UIKit

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!

    var person: Person? {
        didSet {
            self.configureView()
        }
    }

    func configureView() {
        if let person = self.person {
            if let label = self.detailDescriptionLabel {
                label.text = person.fullName
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureView()
    }
}

