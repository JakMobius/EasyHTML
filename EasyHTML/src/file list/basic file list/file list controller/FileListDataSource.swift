//
//  FileListDataSource.swift
//  EasyHTML
//
//  Created by Артем on 06.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

@objc internal protocol FileListDataSource {
    func fileList(fileForRowAt index: Int) -> FSNode
    func countOfFiles() -> Int
    @objc optional func shouldRecognizeForceTouchFor(fileAt index: Int) -> Bool
    @objc optional func canDeleteFile(at index: Int) -> Bool
    @objc optional func shortcutActionsForFile(file: FSNode, at index: Int) -> [ContextMenuAction]
    @objc optional func canMoveFile(at index: Int) -> Bool
}
