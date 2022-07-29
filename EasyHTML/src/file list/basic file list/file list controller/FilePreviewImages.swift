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
    static let fileImageInverted: UIImage = fileImage.invertedImage()!
    static let folderImage: UIImage = UIImage(named: "folder")!
    static let folderImageInverted: UIImage = folderImage.invertedImage()!
    static let codeImage: UIImage = #imageLiteral(resourceName: "cssjs")
    static let codeImageInverted: UIImage = codeImage.invertedImage()!
    static let xmlImage: UIImage = #imageLiteral(resourceName: "html")
    static let xmlImageInverted: UIImage = xmlImage.invertedImage()!
    static let photoImage: UIImage = #imageLiteral(resourceName: "image")
    static let photoImageInverted: UIImage = photoImage.invertedImage()!
    static let zipImage: UIImage = #imageLiteral(resourceName: "zip")
    static let zipImageInverted: UIImage = zipImage.invertedImage()!
    static let txtImage: UIImage = #imageLiteral(resourceName: "txt")
    static let txtImageInverted: UIImage = txtImage.invertedImage()!
    static let linkImage: UIImage = #imageLiteral(resourceName: "shortcut")
    static let linkImageInverted: UIImage = linkImage.invertedImage()!
    static let mdImage: UIImage = #imageLiteral(resourceName: "md")
    static let mdImageInverted: UIImage = mdImage.invertedImage()!
}
