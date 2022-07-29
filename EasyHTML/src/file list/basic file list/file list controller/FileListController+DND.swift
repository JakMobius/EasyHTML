//
//  FileListController+DND.swift
//  EasyHTML
//
//  Created by Артем on 06.06.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

struct UserActivity {
    struct Types {
        static let openFile: String = "com.jakmobius.easyhtml.openfile"
    }
    struct Key {
        static let file: String = "file"
    }
    struct Name {
        static let openFile: String = "openFile"
    }
}

@available(iOS 11.0, *)
extension FileListController: UITableViewDragDelegate, UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        if isLoading {
            return []
        }
        
        session.localContext = self
        
        
        let file = fileListDataSource.fileList(fileForRowAt: indexPath.row)
        
        guard let object = try? JSONEncoder().encode(file) else {
            return []
        }
        
        let activity = NSUserActivity(activityType: UserActivity.Types.openFile)
        
        activity.title = UserActivity.Name.openFile
        activity.userInfo = [
            UserActivity.Key.file : object
        ]
        
        let provider = NSItemProvider(object: file)
        provider.registerObject(activity, visibility: .all)
        return [UIDragItem(itemProvider: provider)]
    }
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        
        for item in coordinator.items {
            item.dragItem.itemProvider.loadObject(ofClass: FSNode.self, completionHandler: { (subject, error) in
                guard let file = subject as? FSNode else { return }
                let session = coordinator.session.localDragSession
                let source: SharedFileContainer
                
                if session == nil {
                    let controller = ReceivedFilesContainer(url: file.url.deletingLastPathComponent())
                    controller.overrideFilename = file.name
                    if let name = item.dragItem.itemProvider.suggestedName {
                        file.name = name
                    }
                    controller.fileListManager = self.fileListManager
                    source = controller
                } else {
                    source = session!.localContext as! SharedFileContainer
                }
                
                let destination = self
                
                if source.url == destination.url && source.sourceType == destination.sourceType {
                    return
                }
                DispatchQueue.main.async {
                    FilesRelocationManager.createFileRelocationTask(
                        source: source,
                        destination: destination,
                        file: file,
                        on: self.view.window!
                    )
                }
            })
        }
    }
}
