import UIKit

internal class FileListCell: UITableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var detailLabel: UILabel!
    @IBOutlet var cellImage: UIImageView!

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        cellImage.contentMode = .scaleAspectFit
    }
}
