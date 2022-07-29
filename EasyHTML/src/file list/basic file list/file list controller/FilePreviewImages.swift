//
//  FilePreviewImages.swift
//  EasyHTML
//
//  Created by Артем on 06.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

internal struct FilePreviewImages {
    static let fileImage: UIImage = #imageLiteral(resourceName: "file.png")
    static let fileImageInversed: UIImage = fileImage.invertedImage()!
    static let folderImage: UIImage = UIImage(named: "folder")!
    static let folderImageInversed: UIImage = folderImage.invertedImage()!
    static let codeImage: UIImage = #imageLiteral(resourceName: "cssjs")
    static let codeImageInversed: UIImage = codeImage.invertedImage()!
    static let xmlImage: UIImage = #imageLiteral(resourceName: "html")
    static let xmlImageInversed: UIImage = xmlImage.invertedImage()!
    static let photoImage: UIImage = #imageLiteral(resourceName: "image")
    static let photoImageInversed: UIImage = photoImage.invertedImage()!
    static let zipImage: UIImage = #imageLiteral(resourceName: "zip")
    static let zipImageInversed: UIImage = zipImage.invertedImage()!
    static let txtImage: UIImage = #imageLiteral(resourceName: "txt")
    static let txtImageInversed: UIImage = txtImage.invertedImage()!
    static let linkImage: UIImage = #imageLiteral(resourceName: "shortcut")
    static let linkImageInversed: UIImage = linkImage.invertedImage()!
    static let mdImage: UIImage = #imageLiteral(resourceName: "md")
    static let mdImageInversed: UIImage = mdImage.invertedImage()!
}
