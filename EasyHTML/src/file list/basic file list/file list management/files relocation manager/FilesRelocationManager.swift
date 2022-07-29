//
//  FilesRelocationManager.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal class FilesRelocationManager: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    // MARK: Поля
    
    var sourceDirectory: URL
    var filesToMove: [FSNode]
    var replicationViews: [ReplicationView]
    var replicationViewsContainer: CustomScrollView
    weak var delegate: FileMovingManagerDelegate! = nil
    var maximumStackedFiles = 7
    var panGestureRecognizer: UIPanGestureRecognizer!
    var touchGestureRecognizer: UILongPressGestureRecognizer!
    var currentLayout: Layout
    weak var parent: UINavigationController!
    var selectedView: UIView! = nil
    var delayTask: DispatchWorkItem! = nil
    var isEditing = false
    var guideWorkItem: DispatchWorkItem! = nil
    var hintType: HintType = .normal
    var hintTimer: Timer! = nil
    var currentSign: WarningSign! = nil
    var isMovingVertical = false
    var isMovingHorizontal = false
    var startGestureLocation: CGPoint!
    var cancelIcon: UIImageView!
    var draggingFile: UIView!
    var sourceType: FileSourceType!
    var sourceContainer: SharedFileContainer!
    var previousTouchLocation: CGPoint! = nil
    
    /**
     Переменная, содержащая состояние блокирования перемещения файла в то или иное расположение
     - warning: Не задавайте значение напрямую, используйте методы `lockDragging` и `unlockDragging`
     */
    
    var draggingIsLocked: Bool = false
    
    // MARK: Методы
    
    private func setupDialog(cells: [UITableViewCell]!) {
        
        var iterator = 0
        for file in filesToMove {
            
            let replicationView = getReplicationView(for: file, index: iterator)
            
            replicationViews.append(replicationView)
            
            if cells != nil {
                if iterator < maximumStackedFiles && iterator < cells.count {
                    
                    let cell = cells[iterator]
                    
                    let frame = replicationView.frame
                    let center = replicationView.center
                    let cellcenter = cell.superview!.convert(cell.center, to: replicationViewsContainer)
                    
                    let tx = cellcenter.x - center.x
                    let ty = cellcenter.y - center.y
                    let scaleX = cell.frame.width / frame.width
                    let scaleY = cell.frame.height / frame.height
                    
                    replicationView.transform = CGAffineTransform(translationX: tx, y: ty).scaledBy(x: scaleX, y: scaleY)
                }
            } else {
                replicationView.transform = CGAffineTransform(translationX: 90, y: -250).scaledBy(x: 2, y: 2)
            }
            
            replicationView.alpha = 0.0
            
            iterator += 1
        }
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.curveEaseOut], animations: {
            self.layout(force: true)
        }, completion: nil)
        
        parent.view.bringSubviewToFront(parent.toolbar)
    }
    
    internal func addFile(file: FSNode) {
        filesToMove.append(file)
        
        let replicationView = getReplicationView(for: file, index: filesToMove.count - 1)
        replicationView.setEditing(self.isEditing)
        replicationView.alpha = 0.0
        
        replicationViews.append(replicationView)
        
        self.layout()
        
        UIView.animate(withDuration: 0.5) {
            replicationView.alpha = 1
        }
    }
    
    internal init(cells: [UITableViewCell]!, files: [FSNode], parent: UINavigationController, source: SharedFileContainer) {
        
        self.sourceDirectory = source.url
        self.replicationViews = []
        self.filesToMove = files
        self.parent = parent
        self.replicationViewsContainer = CustomScrollView()
        self.currentLayout = .normal(size: 20)
        self.sourceContainer = source
        self.sourceType = sourceContainer.sourceType
        
        super.init()
        
        setupScrollView()
        setupDialog(cells: cells)
        setupGestureRecognizers()
        
        if shouldPreviewGuide {
            showGuideMessage()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: .TCThemeChanged, object: nil)
    }
    
    @objc func themeChanged() {
        currentSign?.effect = UIBlurEffect(style: userPreferences.currentTheme.isDark ? .dark : .light)
    }
    
    final func layout(force: Bool = false) {
        switch currentLayout {
        case .normal(let size):
            
            let count = min(filesToMove.count, maximumStackedFiles)
            let dx = min(size / CGFloat(count - 1), 85)
            let dy = 20 / CGFloat(count)
            
            for view in replicationViews {
                
                view.alpha = 1
                
                if view.tag < maximumStackedFiles {
                    
                    if view.superview == nil {
                        replicationViewsContainer.addSubview(view)
                    } else {
                        replicationViewsContainer.bringSubviewToFront(view)
                    }
                    
                    let index = CGFloat(view.tag)
                    
                    let tx = dx * index
                    let ty = dy * index
                    
                    view.transform = CGAffineTransform(translationX: tx, y: ty)
                    
                } else if !force {
                    break
                }
            }
            
            for view in replicationViewsContainer.subviews where view.tag >= maximumStackedFiles {
                view.removeFromSuperview()
            }
            
            replicationViewsContainer.contentSize = .zero
            replicationViewsContainer.isScrollEnabled = false
            
            break
        case .horizontal:
            
            let offset = replicationViewsContainer.contentOffset.x
            var startIndex: Int
            var endIndex: Int
            
            if force {
                startIndex = 0
                endIndex = min(filesToMove.count - 1, maximumStackedFiles - 1)
            } else {
                startIndex = max(Int(offset / 96), 0)
                endIndex = Int((offset + parent.view.frame.width) / 96)
                
                if draggingFile != nil {
                    endIndex += 1
                }
                
                endIndex = min(endIndex, filesToMove.count - 1)
            }
            
            if(startIndex > endIndex) {
                return
            }
            
            var dx = CGFloat(startIndex * 96) + 10
            
            for i in startIndex...endIndex {
                if let draggingfile = draggingFile, draggingfile.tag == i {
                    
                    let percentage = min(-draggingfile.frame.minY / 160, 1)
                    dx += 96 * (1 - percentage)
                } else {
                    let view = replicationViews[i]
                    if view.superview == nil {
                        replicationViewsContainer.addSubview(view)
                    }
                    
                    view.frame.origin = CGPoint(x: dx, y: 5)
                    
                    dx += 96
                }
                
            }
            
            replicationViewsContainer.contentSize = CGSize(width: 96 * filesToMove.count + 12, height: 150)
            
            break
        }
    }
    
    internal func recalculateVisibleViews() {
        if case .horizontal = currentLayout {
            let offset = replicationViewsContainer.contentOffset.x
            let startIndex = max(Int(offset / 96), 0)
            let endIndex = min(Int((offset + parent.view.frame.width) / 96), filesToMove.count - 1)
            
            if(startIndex > endIndex) {
                return
            }
            
            var isChanged = false
            
            for view in replicationViewsContainer.subviews {
                if view.tag < startIndex || view.tag > endIndex {
                    view.removeFromSuperview()
                    isChanged = true
                }
            }
            
            for i in startIndex...endIndex {
                var found = false
                
                for view in replicationViewsContainer.subviews where view.tag == i {
                    found = true
                    break
                }
                
                if !found {
                    replicationViewsContainer.insertSubview(replicationViews[i], at: i - startIndex)
                    isChanged = true
                }
            }
            
            if isChanged { layout() }
        }
    }
    
    internal func scrollViewDidScroll(_ scrollView: UIScrollView) {
        recalculateVisibleViews()
        panGestureRecognizer.isEnabled = false
        panGestureRecognizer.isEnabled = true
        touchGestureRecognizer.isEnabled = false
        touchGestureRecognizer.isEnabled = true
    }
    
    internal func stopRelocatingFiles() {
        guard parent != nil else {return}
        
        UIView.animate(withDuration: 0.5, animations: {
            self.replicationViewsContainer.alpha = 0.0
        }, completion: {
            _ in
            self.replicationViewsContainer.removeFromSuperview()
        })
        
        hideSigns()
        
        delegate?.fileMovingManager(didCompleteRelocatingFiles: self)
        
        let tableview = sourceContainer as? UITableViewController
        tableview?.tableView.reloadData() // TODO: Переписать
    }
    
    final func bounceModify(translation: CGFloat, coefficent: CGFloat = 100) -> CGFloat {
        let translation = translation / coefficent
        var result : CGFloat
        
        if translation < 0 {
            result = 1 - sqrt(1 - translation)
        } else {
            result = sqrt(translation + 1) - 1
        }
        
        return result * coefficent
    }
    
    internal func createCancelIcon() {
        if cancelIcon == nil {
            cancelIcon = UIImageView(image: #imageLiteral(resourceName: "cancel"))
            cancelIcon.layer.cornerRadius = 15
            cancelIcon.clipsToBounds = true
            cancelIcon.translatesAutoresizingMaskIntoConstraints = false
            parent.view.addSubview(cancelIcon)
            
            cancelIcon.rightAnchor.constraint(equalTo: parent.view.leftAnchor).isActive = true
            cancelIcon.centerYAnchor.constraint(equalTo: replicationViewsContainer.centerYAnchor).isActive = true
            cancelIcon.heightAnchor.constraint(equalToConstant: 30).isActive = true
            cancelIcon.widthAnchor.constraint(equalToConstant: 30).isActive = true
            
            UIView.animate(withDuration: 0.15) {
                self.cancelIcon.transform = CGAffineTransform(translationX: 40, y: 0)
            }
        }
    }
    
    internal func removeCancelIcon() {
        if let cancelIcon = cancelIcon {
            self.cancelIcon = nil
            UIView.animate(withDuration: 0.15, animations: {
                cancelIcon.transform = .identity
            }, completion: { _ in
                cancelIcon.removeFromSuperview()
            })
            
            replicationViewsContainer.alpha = 1
        }
    }
    
    /**
     Восстанавливает порядок тегирования слоёв-карточек
     */
    
    final func restoreTaggingOrder(offset: Int = 0) {
        for i in offset..<replicationViews.count {
            replicationViews[i].tag = i
        }
    }
    
    final func animateCardFlight(index: Int) {
        let view = replicationViews[index]
        
        replicationViews.remove(at: index)
        filesToMove.remove(at: index)
        
        restoreTaggingOrder(offset: index)
        
        /*
         Код ниже отвечает за анимацию и подготовку к ней. В душе не понимаю как
         можно было сделать это иначе. Комбинируя линейную и увеличительную трансформацию
         получается какая-то неведомая хрень, поэтому увеличение я оставил работать на
         CGAffineTransform, а линейную трансформацию реализовал при помощи изменения
         view.frame. Никогда я не разбирался с анимацией настолько долго и мучительно.
         А ведь впереди еще куча всего... Боже, дай мне сил.
         */
        
        let position = view.superview!.convert(view.center, to: self.parent.view)
        self.parent.view.addSubview(view)
        
        let scale: CGFloat = 1.5
        
        view.center = CGPoint(x: position.x + view.transform.tx, y: position.y + view.transform.ty)
        view.transform = .identity
        
        UIView.animate(withDuration: 0.3, animations: {
            view.alpha = 0
            view.center = self.parent.view.center
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            
            self.layout()
        }, completion: {
            _ in
            view.removeFromSuperview()
        })
    }
    
    final func fileDeleted(index: Int) {
        let file = filesToMove[index]
        let view = replicationViews[index]
        replicationViews.remove(at: index)
        filesToMove.remove(at: index)
        
        restoreTaggingOrder(offset: index)
        
        UIView.animate(withDuration: 0.3, animations: {
            view.alpha = 0.0
            view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            
            self.layout()
        }) { _ in
            view.removeFromSuperview()
        }
        
        if let controller = sourceContainer {
            controller.hasRetainedFile(file: file)
        }
    }
    
    static func createFileRelocationTask(source: SharedFileContainer, destination: SharedFileContainer, file: FSNode, on view: UIView) {
        
        let task = FilesRelocationTask.getFor(controller: source)
        task.source = source
        task.destination = destination
        task.of += 1
        task.update()
        
        let destinationType = destination.sourceType
        var oldProgress: Float = 0
        
        func progress(_ newProgress: Float) {
            if(task.sourceIsLocal && task.destinationIsLocal && newProgress != 1) {
                return
            }
            
            var delta = newProgress - oldProgress
            oldProgress = newProgress
            
            if(!task.sourceIsLocal && !task.destinationIsLocal) {
                delta /= 2
            }
            
            task.progress += delta
        }
        
        func relocateFile() {
            
            func errorHandler(_ error: Error) {
                progress(0)
                let alert = FilesRelocationTask.failDialog(filename: file.name, error: error) {
                    switch $0 {
                    case .skip, .stop:
                        task.copied += 1
                        progress(1)
                    case .tryAgain:
                        relocateFile()
                    }
                }
                view.addSubview(alert.view)
            }
            
            task.source.prepareToRelocation(file: file, to: destinationType, completion: { (url, error) in
                
                if error != nil {
                    errorHandler(error!)
                    return
                }
                
                oldProgress = 0
                
                task.destination.receiveFile(file: file.name, from: source.sourceType, storedAt: url!, callback: {
                    error in
                    
                    if error == nil {
                        if source.sourceType == destinationType {
                            Editor.fileMoved(file: file, to: task.destination.url.appendingPathComponent(file.name))
                        }
                        task.copied += 1
                        progress(1)
                        return
                    }
                    
                    errorHandler(error!)
                }, progress: progress)
            }, progress: progress)
        }
        
        relocateFile()
    }
    
    final func fileCopied(file: FSNode) {
        if let destination = parent.topViewController as? SharedFileContainer {
            if destination.url == sourceContainer.url {
                destination.hasRetainedFile(file: file)
            } else {
                if let source = sourceContainer {
                    FilesRelocationManager.createFileRelocationTask(
                        source: source,
                        destination: destination,
                        file: file,
                        on: parent.view
                    )
                }
            }
        }
        
        if self.replicationViews.isEmpty {
            self.stopRelocatingFiles()
        } else if self.replicationViews.count == 1, case .horizontal = currentLayout {
            self.currentLayout = .normal(size: 20)
        }
    }
    
    final func filesCopied() {
        
        UIView.animate(withDuration: 0.5, animations: {
            self.replicationViewsContainer.transform = CGAffineTransform(translationX: 0, y: -self.parent.view.frame.height + 250)
            
            self.currentLayout = .normal(size: self.parent.view.frame.width - 100)
            self.layout()
        }, completion: {
            _ in
            self.replicationViewsContainer.removeFromSuperview()
        })
        
        let files = self.filesToMove
        
        self.replicationViews = []
        self.filesToMove = []
        
        if let destination = parent.topViewController as? SharedFileContainer {
            if destination.url == sourceContainer.url {
                stopRelocatingFiles()
                return
            }
            
            if let source = sourceContainer {
                let task = FilesRelocationTask.getFor(controller: sourceContainer)
                
                var iterator = files.makeIterator()
                
                task.source = source
                task.destination = destination
                task.of += files.count
                task.update()
                
                let copied = -1;
                
                var oldProgress: Float = 0
                
                func progress(_ newProgress: Float) {
                    
                    if(task.sourceIsLocal && task.destinationIsLocal && newProgress != 1) {
                        return
                    }
                    
                    var delta = newProgress - oldProgress
                    oldProgress = newProgress
                    
                    if(!task.sourceIsLocal && !task.destinationIsLocal) {
                        delta /= 2
                    }
                    
                    task.progress += delta
                }
                
                func relocateNextFile() {
                    guard let file = iterator.next() else { return }
                    oldProgress = 0;
                    
                    func restore(type: RelocationErrorRestoreType) {
                        switch type {
                        case .skip:
                            progress(1)
                            relocateNextFile()
                        case .stop:
                            let uncopied = files.count - copied;
                            
                            progress(Float(uncopied))
                            
                        case .tryAgain:
                            tryRelocateFile()
                        }
                    }
                    
                    func errorHandler(_ error: Error) {
                        progress(0);
                        let alert = FilesRelocationTask.failDialog(filename: file.name, error: error, callback: restore)
                        parent.view.window?.addSubview(alert.view)
                    }
                    
                    func tryRelocateFile() {
                        
                        let receiveability = destination.canReceiveFile(file: file, from: self.sourceType)
                        
                        if case .no(let reason) = receiveability {
                            
                            let alert = FilesRelocationTask.failDialog(filename: file.name, error: FileRelocationError.unsupportedDestination(reason: reason), callback: restore)
                            parent.view.window?.addSubview(alert.view)
                            return
                        }
                        
                        task.source.prepareToRelocation(file: file, to: destination.sourceType, completion: { (url, error) in
                            
                            if error != nil {
                                errorHandler(error!)
                                return
                            }
                            
                            oldProgress = 0
                            
                            task.destination.receiveFile(file: file.name, from: self.sourceType, storedAt: url!, callback: {
                                error in
                                
                                if self.sourceType! == task.destination.sourceType {
                                    Editor.fileMoved(file: file, to: task.destination.url.appendingPathComponent(file.name))
                                }
                                
                                if error == nil {
                                    task.copied += 1
                                    progress(1)
                                    relocateNextFile()
                                    return
                                }
                                
                                errorHandler(error!)
                            }, progress: progress)
                        }, progress: progress)
                    }
                    
                    tryRelocateFile()
                }
                
                relocateNextFile()
            }
        }
        
        stopRelocatingFiles()
    }
    
    final func cancelFilesRelocation() {
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseOut], animations: {
            self.replicationViewsContainer.transform = CGAffineTransform(translationX: -150, y: 0)
        }, completion: nil)
        
        removeCancelIcon()
        stopRelocatingFiles()
    }
    
    final func setEditing(_ isEditing: Bool) {
        
        if self.isEditing == isEditing {
            return
        }
        
        self.isEditing = isEditing
        for view in replicationViews {
            view.setEditing(isEditing)
        }
    }
    
    final func controllerChanged() {
        panGestureRecognizer.isEnabled = false
        panGestureRecognizer.isEnabled = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
