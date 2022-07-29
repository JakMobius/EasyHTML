//
//  FileDetailViewController.swift
//  EasyHTML
//
//  Created by Артем on 28.01.17.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit
import Zip

class FileDataTableCell: UITableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var detail: UILabel!
    
    override func didMoveToWindow() {
        title.textColor = userPreferences.currentTheme.cellTextColor
        detail.textColor = userPreferences.currentTheme.secondaryTextColor
        detail.adjustsFontSizeToFitWidth = true
        detail.minimumScaleFactor = 0.7
    }
}

class FileDeleteButton: UITableViewCell {
    @IBOutlet var deleteLabel: UILabel!
}

struct FileAction {
    var description: String;
    var action: Selector?;
}

@objc internal class ArchivingOptions: NSObject {
    internal var password: String?
    internal var compressionType: ZipCompression = .defaultCompression
}

@objc internal protocol FileDetailDelegate {
    @objc optional func fileDetail(controller: FileDetailViewController, shouldClone file: FSNode)
    @objc optional func fileDetail(controller: FileDetailViewController, shouldArchive file: FSNode, with options: ArchivingOptions)
    @objc optional func fileDetail(controller: FileDetailViewController, shouldUnarchive file: FSNode)
    @objc optional func fileDetail(controller: FileDetailViewController, shouldDelete file: FSNode)
    @objc optional func fileDetail(controller: FileDetailViewController, shouldRename file: FSNode, to newName: String)
    @objc optional func fileDetail(controller: FileDetailViewController, shouldMove file: FSNode)
}

@objc internal protocol FileDetailDataSource {
    @objc optional func fileDetail(creationDateOf file: FSNode) -> Date?
    @objc optional func fileDetail(modificationDateOf file: FSNode) -> Date?
    @objc optional func fileDetail(sizeOf file: FSNode, completion: @escaping (Int64) -> ()) -> CancellableRequest!
    @objc optional func fileDetail(sourceNameOf file: FSNode) -> String
    @objc optional func fileDetail(pathTo file: FSNode) -> String
    
    /**
        Метод вызывается при нажатии на кнопку "Поделиться"
     
     
     - parameter controller: Контроллер для отображения на нём `UIActivityController` при необходимости предварительно скачать файл
     - parameter file: Файл, который должен быть отправлен. Значение идентично `controller.file`
     - parameter callback: Функция, которая должна быть вызвана по завершению кэширования. Первый аргумент является бинарным флагом, обозначающим необходимость удаления файла после его отправки в случае если он был кеширован во временную папку. Второй аргумент должен содержать в себе URL-указатель на локально-кешированный файл. Если в процессе кеширования произошла ошибка, функция может быть не вызвана.
     */
    
    @objc optional func fileDetail(controller: FileDetailViewController, objectsToShare file: FSNode, callback: (Bool, URL) -> ())
}

internal class FileDetailViewController: AlternatingColorTableView, UITextFieldDelegate, ArchiveDialogDelegate
{
    internal enum Action {
        case share, move, rename, delete, clone, archive, unarchive
    }
    
    internal static func getNew(observatingFile: FSNode, actions: [Action]) -> FileDetailViewController {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "fileDetail") as! FileDetailViewController
        
        controller.file = observatingFile
        controller.actions = actions
        
        return controller
    }
    
    private var currentActionList: [FileAction] = []
    private var actions: [Action] = []
    private var isFolder = false
    private var path = ""
    private var currentActionsLength = 0
    internal var fileUpdatedCallback: (() -> ())? = nil
    
    internal weak var delegate: FileDetailDelegate? = nil
    internal weak var dataSource: FileDetailDataSource? = nil
    
    private var file: FSNode!
    
    private var nameCell: InputCell? = nil
    
    @objc func unarchive() {
        delegate?.fileDetail?(controller: self, shouldUnarchive: file!)
    }
    
    @objc func archive() {
        
        let archiveDialogController = ArchiveDialogTableViewController()
        
        archiveDialogController.delegate = self
        archiveDialogController.file = file
        
        navigationController?.pushViewController(archiveDialogController, animated: true)
    }
    
    internal func archiveDialog(dialog controller: ArchiveDialogTableViewController, shouldArchive file: FSNode, with options: ArchivingOptions) {
        
        controller.dismiss(animated: true, completion: {
            self.delegate?.fileDetail?(controller: self, shouldArchive: file, with: options)
        })
    }
    
    override internal func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section != 0
    }
    
    @objc func shareFile() {
        
        self.dataSource?.fileDetail?(controller: self, objectsToShare: self.file, callback: {
            shouldDelete, url in
            
            let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            let popover = activityController.popoverPresentationController
            let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1))!
            
            if shouldDelete {
                activityController.completionWithItemsHandler = {
                    _, _, _, _ in
                    try? FileManager.default.removeItem(at: url)
                }
            }
            
            popover?.sourceView = cell
            popover?.sourceRect = cell.bounds
            
            self.present(activityController, animated: true, completion: nil)
        })
    }
    
    @objc func relocateFile() {
        delegate?.fileDetail?(controller: self, shouldMove: file!)
        
        dismiss(animated: true, completion: nil)
    }
    
    @objc func cloneFile() {
        delegate?.fileDetail?(controller: self, shouldClone: file!)
        
        dismiss(animated: true, completion: nil)
    }
    
    private func deleteItem(cell: UITableViewCell) {
        let isfile = file is FSNode.File
        
        func delete(action: UIAlertAction) -> Void
        {
            TemproraryFileMetadataManager.clearMetadata(forFile: file!)
            
            delegate?.fileDetail?(controller: self, shouldDelete: file!)
            
            isDisappeared = true
            dismiss(animated: true, completion: nil)
        }
        
        let deleteAlert = UIAlertController(title: localize(isfile ? "filedeletealert" : "folderdeletealert"), message: localize("cannotbeundone"), preferredStyle: .actionSheet)
        deleteAlert.addAction(UIAlertAction(title: localize("delete"), style: .destructive, handler:delete))
        deleteAlert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel, handler:nil))
        
        deleteAlert.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: cell.bounds.origin.x + cell.bounds.width, y: cell.bounds.origin.y + 20), size: CGSize(width: 50, height: 30))
        deleteAlert.popoverPresentationController?.sourceView = cell.contentView
        
        self.present(deleteAlert, animated: true, completion: nil)
    }
    
    override internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 2) {
            deleteItem(cell: tableView.cellForRow(at: indexPath)!)
        }
        
        if(indexPath.section == 1) {
            if let action = currentActionList[indexPath.row].action {
                self.perform(action)
            } else {
               /* let alert = TCAlertController.getNew()
                
                alert.applyDefaultTheme()
                
                alert.contentViewHeight = 110
                alert.constructView()
                alert.makeCloseableByTapOutside()
                alert.headerText = LocalizedString("indev")
                
                let imageView = UIImageView(frame: CGRect(x: 75, y: 0, width: 100, height: 100))
                imageView.image = #imageLiteral(resourceName: "comingsoon")
                
                alert.contentView.addSubview(imageView)
                
                alert.animation = TCAnimation(animations: [.scale(0.8, 0.8), .opacity], duration: 0.5, delay: 0.0, usingSpringWithDamping: 0.6)
                alert.closeAnimation = alert.animation
                
                alert.addAction(action: TCAlertAction(text: LocalizedString("indevok"), shouldCloseAlert: true))
                
                let window = UIApplication.shared.delegate!.window!!
                window.addSubview(alert.view)*/
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private struct FileInfoSections {
        var name: String, value: String
    }
    
    private var attributes = [FileInfoSections]()
    private var nodeSizeCalculationTask: CancellableRequest! = nil
    private static let dateFormatter = { () -> DateFormatter in
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateFormat = "dd MMMM yyyy hh:mm:ss"
        
        return dateFormatter
    }()
    
    private func readAttributes() {
        
        var localizedModificationDate: String? = nil
        var localizedCreationDate: String? = nil
        
        if let modificationDate = dataSource?.fileDetail?(modificationDateOf: file) {
            localizedModificationDate = FileDetailViewController.dateFormatter.string(for: modificationDate)
        }
        
        if let creationDate = dataSource?.fileDetail?(creationDateOf: file) {
            localizedCreationDate = FileDetailViewController
                .dateFormatter.string(for: creationDate)
        }
        
        
        var path = dataSource?.fileDetail?(pathTo: file) ?? file.url.deletingPathExtension().path
        
        if !path.isEmpty && !path.hasPrefix("/") {
            path = "/" + path
        } else if path == "/" {
            path = ""
        }
        
        let localizedPath = path.replacingOccurrences(of: "/", with: " ▸ ")
        
        let locationName = dataSource?.fileDetail?(sourceNameOf: file) ?? localize("documents")
        
        attributes = [.init(
                name: localize("aboutfilepath"),
                value: locationName + localizedPath
            ), .init(
                name: localize("aboutfilesize"),
                value: localize("calculating")
            )
        ]
        
        if let request = self.dataSource?.fileDetail(sizeOf:completion:) {
            nodeSizeCalculationTask = request(file!, {
                [weak self] size in
                
                guard let slf = self else { return }
                
                if size >= 0 {
                    let localizedSize = "\(size) \(localize("bytes"))"
                    
                    slf.attributes[1].value = localizedSize
                } else {
                    slf.attributes[1].value = localize("unknown")
                }
                
                slf.tableView.reloadRows(at: [IndexPath(row: 2, section: 0)], with: .fade)
            })
        } else {
            attributes[1].value = localize("unknown")
        }
        
        if let folder = file as? FSNode.Folder {
            let objects = folder.countOfFilesInside
            if objects >= 0 {
                attributes.append(.init(name: localize("aboutfileobjects"), value: String(objects)))
            }
        }
        if let date = localizedModificationDate {
            attributes.append(.init(name: localize("aboutfilemodified"), value: date))
        }
        if let date = localizedCreationDate {
            attributes.append(.init(name: localize("aboutfilecreated"), value: date))
        }
        
    }
    
    private func setupNavigationBar() {
        self.navigationItem.title = isFolder ? localize("aboutfolder") : localize("aboutfile")
        
        let button = UIBarButtonItem()
        button.target = self
        button.action = #selector(close)
        button.title = localize("ready")
        
        self.navigationItem.leftBarButtonItem = button
    }
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        if(file == nil) {
            fatalError("[EasyHTML] [FileDetailViewController] Do not use init() to create new instance of this type. Use static function \"getNew(observatingFile: FSObject)\" instead")
        }
        
        readAttributes()
        updateCurrentActionList()
        
        isFolder = file is FSNode.Folder;
        path = file.url.deletingLastPathComponent().path
        
        setupNavigationBar()
        updateStyle()
        
        tableView.register(InputCell.self, forCellReuseIdentifier: "name")
        tableView.register(LabelCell.self, forCellReuseIdentifier: "data")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        if _testing {
            tableView.accessibilityLabel = "About"
        }
    }
    
    @objc func close(sender: UIBarButtonItem)
    {
        viewWillDisappear(true)
        self.view.endEditing(true)
        self.dismiss(animated: true, completion: nil)
    }
    
    func updateCurrentActionList()
    {
        currentActionList = []
        if actions.contains(.share) {
            currentActionList.append(FileAction(description: "share", action: #selector(shareFile)))
        }
        if actions.contains(.move) {
            currentActionList.append(FileAction(description: "movefile", action: #selector(relocateFile)))
        }
        if actions.contains(.clone) {
            currentActionList.append(FileAction(description: "clonefile", action: #selector(cloneFile)))
        }
        if actions.contains(.unarchive) {
            currentActionList.append(FileAction(description: "unarchive", action: #selector(unarchive)))
        }
        if actions.contains(.archive) {
            currentActionList.append(FileAction(description: "archive", action: #selector(archive)))
        }
    }
    
    internal override func viewDidDisappear(_ animated: Bool) {
        nodeSizeCalculationTask?.cancel()
    }
    
    var isDisappeared = false
    override internal func viewWillDisappear(_ animated: Bool) {
        if(isDisappeared) {return}
        isDisappeared = true;
        
        let name = nameCell!.input.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if(name != file.name) {
            delegate?.fileDetail?(controller: self, shouldRename: file, to: name)
        }
        
    }
    
    override internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            if indexPath.row == 0
            {
                let cell = tableView.dequeueReusableCell(withIdentifier: "name", for: indexPath) as! InputCell
                
                cell.label.text = localize("aboutfilename")
                cell.label.font = UIFont.systemFont(ofSize: 15)
                cell.label.textColor = userPreferences.currentTheme.cellTextColor
                cell.input.font = cell.label.font
                cell.input.text = file.name
                
                if actions.contains(.rename) {
                    cell.input.isEnabled = true
                    cell.input.textColor = userPreferences.currentTheme.cellTextColor
                } else {
                    cell.input.isEnabled = false
                    cell.input.textColor = userPreferences.currentTheme.secondaryTextColor
                }
                
                cell.input.delegate = self
                nameCell = cell
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "data", for: indexPath) as! LabelCell
                
                cell.label.textColor = userPreferences.currentTheme.cellTextColor
                cell.rightLabel.textColor = userPreferences.currentTheme.secondaryTextColor
                cell.label.font = UIFont.systemFont(ofSize: 15)
                cell.rightLabel.font = UIFont.systemFont(ofSize: 15)
                
                if indexPath.row == 1 {
                    cell.rightLabel.lineBreakMode = .byTruncatingHead
                }
                
                let attribute = attributes[indexPath.row - 1]
                
                cell.label.text = attribute.name
                cell.rightLabel.text = attribute.value
                
                return cell
            }
        } else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            
            cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor
            cell.textLabel!.text = localize(currentActionList[indexPath.row].description)
            cell.textLabel!.lineBreakMode = .byTruncatingHead
            cell.textLabel!.adjustsFontSizeToFitWidth = true
            cell.textLabel!.minimumScaleFactor = 0.7
            cell.textLabel!.font = UIFont.systemFont(ofSize: 15)
            cell.accessoryType = .disclosureIndicator
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Delete", for: indexPath) as! FileDeleteButton
            cell.deleteLabel.text = localize("delete")
            return cell
        }
    }
    
    internal func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        return !string.contains("/")
    }
    
    internal override func numberOfSections(in tableView: UITableView) -> Int {
        if(actions.contains(.delete)) {
            return 3
        } else if(currentActionList.isEmpty) {
            return 1
        }
        return 2
    }
    
    internal override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(section == 0) {
            return attributes.count + 1
        } else if(section == 1) {
            return currentActionList.count
        } else {
            return 1
        }
    }
    
    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    internal func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return userPreferences.currentTheme.statusBarStyle
    }
}
