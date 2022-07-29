//
//  FileListDelegate.swift
//  EasyHTML
//
//  Created by Артем on 06.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

@objc internal protocol FileListDelegate {
    @objc optional func fileList(selectedFileAt index: Int)
    @objc optional func fileList(deleted file: FSNode)
}

