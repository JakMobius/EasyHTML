//
//  AboutCell.swift
//  EasyHTML
//
//  Created by Артем on 20.01.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

class AboutCell: UITableViewCell {

    @IBOutlet var textView: UITextView!

    override func didMoveToWindow() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        textView.text = localize("copyrights", .copyrights).replacingOccurrences(of: "{v}", with: version)

        selectionStyle = .none
    }

    override func setSelected(_ selected: Bool, animated: Bool) {

    }
}

