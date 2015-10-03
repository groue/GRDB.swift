import UIKit

class DetailViewController: UIViewController {
    @IBOutlet weak var detailDescriptionLabel: UILabel!

    var person: Person! {
        didSet {
            self.configureView()
        }
    }

    func configureView() {
        guard isViewLoaded() else {
            return
        }
        detailDescriptionLabel.text = person.fullName
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        configureView()
    }
}

