//
//  FileQuickInfoView.swift
//  EasyHTML
//
//  Created by Артем on 09/09/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

private var extensionDescriptions: [String: String] = [
    "txt": "text",
    "html": "webpage",
    "htm": "webpage",
    "js": "jsfile",
    "plist": "plistfile",
    "m": "objcfile",
    "c": "cfile",
    "cpp": "cppfile",
    "hpp": "headerfile",
    "h": "headerfile",
    "cs": "csfile",
    "swift": "swiftfile",
    "py": "pythonfile",
    "pas": "pascalfile",
    "md": "mdfile",
    "f": "forfile",
    "f77": "forfile",
    "for": "forfile",
    "ftn": "forfile",
    "fs": "fsharpfile",
    "fsx": "fsharpfile",
    "jpg": "jpegimage",
    "jpeg": "jpegimage",
    "bmp": "bmpimage",
    "tiff": "tiffimage",
    "gif": "gifimage",
    "png": "pngimage",
    "ico": "icoimage",
    "pdf": "pdf",
    "mp3": "audio",
    "wav": "audio",
    "ogg": "audio",
    "m4a": "audio",
    "mp4": "film",
    "avi": "film",
    "zip": "archive",
    "rar": "archive"
]

internal class FileQuickInfo: UIView {

    let titleLabel = UILabel()
    let descriptionLabel = UILabel()
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 80).isActive = true

        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(imageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false

        imageView.leftAnchor.constraint(equalTo: leftAnchor, constant: 20).isActive = true
        imageView.topAnchor.constraint(equalTo: topAnchor, constant: 20).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20).isActive = true
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true

        titleLabel.leftAnchor.constraint(equalTo: imageView.rightAnchor, constant: 10).isActive = true
        titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20).isActive = true
        titleLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        titleLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -10).isActive = true

        descriptionLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor, constant: 0).isActive = true
        descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2).isActive = true
        descriptionLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        descriptionLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -10).isActive = true

        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        descriptionLabel.font = UIFont.systemFont(ofSize: 13)

        descriptionLabel.textColor = UIColor(white: 0.6, alpha: 1)

        imageView.contentMode = .scaleAspectFit
    }

    func describeFile(file: FSNode, previewImage: UIImage! = nil) {

        titleLabel.text = file.name

        let desc: String

        if let file = file as? FSNode.File {

            let ext = file.url.pathExtension

            if let description = extensionDescriptions[ext] {
                desc = file.localizedFileSize + " • " + localize(description, .fileDesc)
            } else {
                desc = file.localizedFileSize + " • " + localize("general", .fileDesc)
                        .replacingOccurrences(of: "#", with: ext.uppercased())
            }

            imageView.image = previewImage ?? getFilePreviewImageByExtension(ext)
        } else if let folder = file as? FSNode.Folder {

            let countOfFiles = folder.countOfFilesInside

            if countOfFiles == -1 {
                desc = localize("folder", .fileDesc)
            } else if countOfFiles == 0 {
                desc = localize("emptyfolder", .files)
            } else {
                desc = localize("folderwithfiles", .fileDesc)
                        .replacingOccurrences(of: "#", with: String(countOfFiles))
            }


            imageView.image = previewImage ?? FilePreviewImages.folderImage
        } else {
            desc = localize("unknown", .fileDesc)

            imageView.image = previewImage ?? FilePreviewImages.fileImage
        }

        descriptionLabel.text = desc
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
