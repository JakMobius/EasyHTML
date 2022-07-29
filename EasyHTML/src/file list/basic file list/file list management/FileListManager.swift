import UIKit

@objc internal protocol FileMovingManagerDelegate {
    @objc func fileMovingManager(didCompleteRelocatingFiles manager: FilesRelocationManager)
}

enum FileRelocationError: LocalizedError {
    case unsupportedDestination(reason: FilesRelocationManager.RelocationForbiddenReason)
    case couldNotReadFile
    
    var localizedDescription: String {
        switch self {
        case .unsupportedDestination(let reason):
            return reason.localizedDescription
        case .couldNotReadFile:
            return localize("couldnotreadfile")
        }
    }
    
    var errorDescription: String? {
        return localizedDescription
    }
}

enum RelocationErrorRestoreType {
    case stop, skip, tryAgain
}

typealias FilesRelocationCompletion = (Error?) -> ()

protocol SharedFileContainer {
    func canReceiveFile(file: FSNode, from source: FileSourceType) -> FilesRelocationManager.FileReceiveability
    func receiveFile(file: String, from source: FileSourceType, storedAt atURL: URL, callback: @escaping FilesRelocationCompletion, progress: @escaping (Float) -> ())
    func prepareToRelocation(file: FSNode, to destination: FileSourceType, completion: @escaping (URL?, Error?) -> (), progress: @escaping (Float) -> ())
    func hasRetainedFile(file: FSNode)
    func updateFilesRelocationState(task: FilesRelocationTask)
    var url: URL! { get }
    var sourceType: FileSourceType { get }
    var canReceiveFiles: Bool { get }
    var fileListManager: FileListManager! { get }
}

internal class FilesRelocationTask {
    var copied: Int
    
    var of: Int {
        didSet {
            guard !_preventRecursy else { return }
            update()
        }
    }
    
    var progress: Float {
        didSet {
            guard !_preventRecursy else { return }
            update()
        }
    }
    
    private var _preventRecursy = false
    
    private(set) var sourceIsLocal = false
    private(set) var destinationIsLocal = false
    
    var fractionCompleted: Float {
        return progress / Float(of)
    }
    
    var source: SharedFileContainer! {
        didSet {
            sourceIsLocal = source != nil && (source.sourceType == .local)
        }
    }
    
    var destination: SharedFileContainer! {
        didSet {
            destinationIsLocal = destination != nil && (destination.sourceType == .local)
        }
    }
    
    var isZero: Bool {
        return copied == 0 && of == 0
    }
    
    static var zero: FilesRelocationTask {
        get {
            return FilesRelocationTask(copied: 0, of: 0)
        }
    }
    
    /**
     Сохраняет задачу перемещения в реестре менеджера файлов, если задача в процессе, или удаляет, если задача завершена.
     */
    
    func save() {
        // Так не делать:
        // var db = source.fileListManager.relocationSources[source.sourceType]!
        // Массив копируется и меняется его копия, а не изначальное хранилище.
        
        if isZero {
            source.fileListManager.relocationSources[source.sourceType]!.removeValue(forKey: source.url!)
        } else {
            source.fileListManager.relocationSources[source.sourceType]![source.url!] = self
        }
    }
    
    func update() {
        if(copied == of) {
            _preventRecursy = true
            of = 0
            copied = 0
            progress = 0
            save()
            _preventRecursy = false
        }
        save()
        destination.updateFilesRelocationState(task: self)
    }
    
    init(copied: Int, of: Int) {
        self.copied = copied
        self.of = of
        self.progress = 0
        self.sourceIsLocal = false
        self.destinationIsLocal = false
    }
    
    static func failDialog(filename: String, error: Error!, callback: @escaping (RelocationErrorRestoreType) -> ()) -> TCAlertController {
        
        let alert = TCAlertController.getNew()
        
        alert.applyDefaultTheme()
        
        alert.contentViewHeight = 50
        alert.constructView()
        
        let textView = alert.addTextView()
        
        textView.text = localize("failedtocopyfile")
            .replacingOccurrences(of: "#", with: filename)
        textView.text! += "\n"
        textView.text! += error.localizedDescription
        
        alert.header.text = localize("copyingerror")
        
        alert.addAction(action: TCAlertAction(text: localize("tryagain"), action: { (_, _) in
            callback(.tryAgain)
        }, shouldCloseAlert: true))
        alert.addAction(action: TCAlertAction(text: localize("skipfile"), action: { (_, _) in
            callback(.skip)
        }, shouldCloseAlert: true))
        alert.addAction(action: TCAlertAction(text: localize("stopcopying"), action: { (_, _) in
            callback(.stop)
        }, shouldCloseAlert: true))
        
        return alert
    }
    
    static func getFor(controller: SharedFileContainer) -> FilesRelocationTask {
        var db = controller.fileListManager.relocationSources[controller.sourceType]
        
        if db == nil {
            db = FileListManager.RelocationTasksInfo()
            controller.fileListManager.relocationSources[controller.sourceType] = db
        }
        
        if let value = db![controller.url!] {
            return value;
        }
        return .zero
    }
}

internal class FileListManager: NSObject, FileMovingManagerDelegate {
    
    typealias RelocationTasksInfo = [URL : FilesRelocationTask]
    
    internal var relocationSources: [FileSourceType : RelocationTasksInfo] = [:]
    internal var relocationTasksInfo: RelocationTasksInfo = [:]
    internal var filesRelocationManager: FilesRelocationManager! = nil
    internal weak var parent: UINavigationController!
    internal var isRelocatingFiles: Bool {
        get {
            return filesRelocationManager != nil
        }
    }
    
    internal func startMovingFiles(cells: [UITableViewCell]!, files: [FSNode], from: SharedFileContainer! = nil) {
        if isRelocatingFiles {
            print("startMovingFiles(sourceFolder:cells:files:from:) called within file moving")
            return
        }
        
        guard let controller = from ?? (parent.topViewController as? SharedFileContainer) else {
            print("startMovingFiles(sourceFolder:cells:files:from:) Source controller is not provided. NavigationController topViewController is not SharedFileContainer.")
            return
        }
        
        filesRelocationManager = FilesRelocationManager(cells: cells, files: files, parent: parent, source: controller)
        filesRelocationManager.delegate = self
    }
    
    internal func fileMovingManager(didCompleteRelocatingFiles manager: FilesRelocationManager) {
        filesRelocationManager = nil
        
        for controller in parent.viewControllers {
            if let controller = controller as? FileListController {
                controller.stopMovingFiles()
            }
        }
    }
    
    /// Возвращает контроллер, записанный в памяти менеджера перемещения файлов, имеющий указанный тип.
    
    final func getCachedController(for url: URL, with sourceType: FileSourceType) -> UIViewController! {
        for (_, source) in relocationSources {
            for (_, value) in source {
                
                if value.source.sourceType == sourceType && value.source.url.path == url.path, let controller = value.source as? UIViewController {
                    return controller
                }
                if value.destination.sourceType == sourceType && value.destination.url.path == url.path, let controller = value.destination as? UIViewController {
                    return controller
                }
            }
        }
        
        return nil
    }
    
    internal init(parent: UINavigationController) {
        self.parent = parent
    }
}
