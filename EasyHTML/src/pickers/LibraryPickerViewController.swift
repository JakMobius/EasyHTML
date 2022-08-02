//
//  LibraryPickerViewController.swift
//  EasyHTML
//
//  Created by Артем on 16.02.2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

internal class LibrarySection {
    internal var name: String
    internal var libraries: [Library] = []

    internal init(name: String) {
        self.name = name
    }
}

internal class Library: NSObject {
    /// Library name
    internal var name: String
    /// Library network location
    internal var networkURL: String
    /// Indicates if this library is already loaded on the device
    internal var isLoaded: Bool
    /// Indicates if this library is currently being loaded on the device
    internal var isLoading: Bool = false
    /// The section, containing this library
    internal var section: LibrarySection
    /// Extension of the file with library (including dot)
    internal var ext: String

    internal init(name: String, networkURL: String, isLoaded: Bool, section: LibrarySection) {
        self.name = name

        self.isLoaded = isLoaded
        self.section = section

        let url = URL(string: networkURL)
        if (url == nil) {
            self.networkURL = ""
            ext = ""
        } else {
            self.networkURL = networkURL
            ext = "." + url!.pathExtension
        }
    }

    internal func getLocalFileURL() -> URL {
        URL(fileURLWithPath: applicationPath + "/libraries/").appendingPathComponent(section.name).appendingPathComponent(name + ext)
    }
}

private class LibraryPickerDownloadManager: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {

    internal static var id: UInt64 = 0

    var downloadingLibrary: Library!
    var cell: LibraryPickerTableViewCell!
    var progressBegun = false

    var session: URLSession {
        get {
            let config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background\(LibraryPickerDownloadManager.id)")

            LibraryPickerDownloadManager.id += 1

            return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        }
    }

    private override init() {
        super.init()
    }

    internal static func downloadLibrary(cell: LibraryPickerTableViewCell) {

        let progressView = cell.downloadIndicatorView
        guard let library = progressView.indicatorLayer.library else {

            print("Failed to load library: LibraryPickerDownloadManager.downloadLibrary: LibraryPickerTableViewCell must be initialized");
            return
        }

        DispatchQueue(label: "easyhtml.librarydownloader.downloadqueue").async {
            guard let url = URL(string: library.networkURL) else {
                print("Failed to load library: Wrong URL specified at library \(library.section.name) -> \(library.name)")
                progressView.indicatorLayer.loadingProgress = 1
                DispatchQueue.main.sync {
                    progressView.layer.setNeedsDisplay()
                    progressView.indicatorLayer.setNeedsDisplay()
                }
                return
            }
            let manager = LibraryPickerDownloadManager()
            manager.downloadingLibrary = library
            manager.downloadingLibrary.isLoading = true
            manager.cell = cell
            progressView.indicatorLayer.loadingProgress = 0
            let indicatorLayer = progressView.indicatorLayer

            DispatchQueue.main.sync {
                cell.updateState()
            }

            LibraryPickerViewController.downloadManagers.append(manager)

            manager.session.downloadTask(with: url).resume()

            let pi2 = 2 * Double.pi

            while (library.isLoading) {
                if (manager.progressBegun) {
                    indicatorLayer.delta += 0.15
                } else {
                    indicatorLayer.delta -= 0.05
                }
                indicatorLayer.delta = indicatorLayer.delta.truncatingRemainder(dividingBy: pi2)
                DispatchQueue.main.sync {
                    progressView.layer.setNeedsDisplay()
                    progressView.indicatorLayer.setNeedsDisplay()
                }
                usleep(25000)
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progressBegun = true
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

            cell.downloadIndicatorView.indicatorLayer.loadingProgress = progress
        }
    }

    func setErrorState() {
        downloadingLibrary.isLoading = false
        cell.downloadIndicatorView.indicatorLayer.loadingProgress = 1
        updateCellAsync()
    }

    func setSuccessState() {
        downloadingLibrary.isLoaded = true
        downloadingLibrary.isLoading = false
        cell.downloadIndicatorView.indicatorLayer.loadingProgress = -1
        updateCellAsync()
    }

    func updateCellAsync() {
        DispatchQueue.main.sync {
            cell.downloadIndicatorView.layer.setNeedsDisplay()
            cell.downloadIndicatorView.indicatorLayer.setNeedsDisplay()
            cell.updateState()
        }
    }

    func terminate() {
        session.invalidateAndCancel()
        if let index = LibraryPickerViewController.downloadManagers.firstIndex(of: self) {
            LibraryPickerViewController.downloadManagers.remove(at: index)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        terminate()

        do {
            try FileManager.default.copyItem(at: location, to: downloadingLibrary.getLocalFileURL())
        } catch {
            setErrorState()
            return
        }

        setSuccessState()

        try? FileManager.default.removeItem(at: location)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        downloadingLibrary.isLoading = false
        let indicatorLayer = cell.downloadIndicatorView.indicatorLayer
        if (error == nil) {
            indicatorLayer.loadingProgress = -1
            downloadingLibrary.isLoaded = true
        } else {
            indicatorLayer.loadingProgress = 1
        }
    }
}

internal class LibraryPickerTableViewCellUniversalLayer: CALayer {
    var library: Library? = nil
    var loadingProgress: Double = -1
    var delta = 0.0

    required override internal init() {
        super.init()
        contentsScale = UIScreen.main.scale
        needsDisplayOnBoundsChange = true
    }

    required internal init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    required override internal init(layer: Any) {
        super.init(layer: layer)
    }

    override internal func draw(in ctx: CGContext) {
        ctx.setLineWidth(1.5)
        ctx.setFillColor(userPreferences.currentTheme.cellColor1.cgColor)
        ctx.fill(bounds)

        if library == nil {
            return
        }

        if (library!.networkURL.isEmpty) {
            ctx.draw(#imageLiteral(resourceName: "downloaderror").maskWithColor(color: #colorLiteral(red: 1, green: 0.4340401786, blue: 0.3397042411, alpha: 1))!.cgImage!, in: bounds)
            return
        }

        if (loadingProgress > -1) {
            if (!library!.isLoaded) {
                if (loadingProgress == 1) {
                    ctx.draw(#imageLiteral(resourceName: "downloaderror").maskWithColor(color: #colorLiteral(red: 1, green: 0.4340401786, blue: 0.3397042411, alpha: 1))!.cgImage!, in: bounds)
                } else {

                    let progress = 0.1 + loadingProgress * 0.9
                    let startPoint = CGPoint(x: 11 + cos(delta) * 10, y: 11 + sin(delta) * 10)

                    ctx.setStrokeColor(userPreferences.currentTheme.buttonDarkColor.cgColor)
                    ctx.beginPath()
                    ctx.move(to: startPoint)
                    ctx.addArc(center: CGPoint(x: 11, y: 11), radius: 10, startAngle: CGFloat(delta), endAngle: CGFloat(.pi * 2 * progress + delta), clockwise: false)
                    ctx.drawPath(using: .fillStroke)
                }
            }
        } else if (library!.isLoaded) {
            ctx.draw(#imageLiteral(resourceName: "downloaded").maskWithColor(color: userPreferences.currentTheme.buttonDarkColor)!.cgImage!, in: bounds)
        } else {
            ctx.draw(#imageLiteral(resourceName: "download").maskWithColor(color: userPreferences.currentTheme.buttonDarkColor)!.cgImage!, in: bounds)
        }
    }
}

class LibraryPickerTableViewCellProgressView: UIView {
    var indicatorLayer = LibraryPickerTableViewCellUniversalLayer()

    override func didMoveToSuperview() {
        indicatorLayer.frame = bounds
        layer.masksToBounds = true
        layer.cornerRadius = 10.5

        layer.addSublayer(indicatorLayer)
    }
}

class LibraryPickerTableViewCell: UITableViewCell {
    var downloadIndicatorView = LibraryPickerTableViewCellProgressView()

    override func didMoveToWindow() {
        downloadIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        downloadIndicatorView.frame = CGRect(x: 0, y: 0, width: 22, height: 22)

        contentView.addSubview(downloadIndicatorView)

        downloadIndicatorView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20).isActive = true
        downloadIndicatorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        downloadIndicatorView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        downloadIndicatorView.heightAnchor.constraint(equalToConstant: 22).isActive = true
    }

    func updateState() {
        if let library = downloadIndicatorView.indicatorLayer.library {
            if (library.isLoaded) {
                detailTextLabel!.textColor = userPreferences.currentTheme.secondaryTextColor
                detailTextLabel!.text = getLocalizedFileItemSize(at: library.getLocalFileURL().path)
            } else {
                if (downloadIndicatorView.indicatorLayer.loadingProgress == 1) {
                    detailTextLabel!.textColor = #colorLiteral(red: 1, green: 0.4340401786, blue: 0.3397042411, alpha: 1)
                    detailTextLabel!.text = localize("libraryloadingerror")
                } else if (library.isLoading) {
                    detailTextLabel!.textColor = userPreferences.currentTheme.secondaryTextColor
                    detailTextLabel!.text = localize("libraryloading")
                } else {
                    detailTextLabel!.textColor = userPreferences.currentTheme.secondaryTextColor
                    detailTextLabel!.text = localize("notloadedlibrary")
                }
            }
        }

        downloadIndicatorView.indicatorLayer.setNeedsDisplay()
        downloadIndicatorView.layer.setNeedsDisplay()
    }
}

@objc internal protocol LibraryPickerDelegate {
    @objc optional func libraryPicker(didSelect library: Library)
}

internal class LibraryPickerViewController: AlternatingColorTableView, UISearchResultsUpdating {

    internal enum LibraryType: String {
        case css = "css-libs", js = "js-libs"
    }

    fileprivate static var downloadManagers = [LibraryPickerDownloadManager]()

    private let searchController = UISearchController(searchResultsController: nil)
    private var librarySections = [LibrarySection]()
    private var filteredLibraries = [Library]()
    internal var libraryType: LibraryType! = nil
    internal var libraryPickerDelegate: LibraryPickerDelegate? = nil

    func searchBarIsEmpty() -> Bool {
        searchController.searchBar.text?.isEmpty ?? true
    }

    override internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedLibrary = getCurrentLibrary(for: indexPath)

        if (selectedLibrary.isLoaded) {

            if (isFiltering()) {
                dismiss(animated: true, completion: nil)
            }
            dismiss(animated: true, completion: nil)

            libraryPickerDelegate?.libraryPicker?(didSelect: selectedLibrary)

        } else if (!selectedLibrary.isLoading) {
            LibraryPickerDownloadManager.downloadLibrary(cell: tableView.cellForRow(at: indexPath) as! LibraryPickerTableViewCell)
        }
    }

    func filterContentForSearchText(_ searchText: String) {

        filteredLibraries = []
        let searchText = searchText.lowercased()

        librarySections.forEach {
            librarySection in
            librarySection.libraries.forEach {
                library in

                if library.name.lowercased().contains(searchText) {
                    filteredLibraries.append(library)
                }
            }
        }

        tableView.reloadData()
    }

    func isFiltering() -> Bool {
        searchController.isActive && !searchBarIsEmpty()
    }

    internal func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }

    func getCurrentLibrary(for indexPath: IndexPath) -> Library {
        if (isFiltering()) {
            return filteredLibraries[indexPath.row]
        } else {
            return librarySections[indexPath.section].libraries[indexPath.row]
        }
    }

    override internal func viewDidLoad() {
        super.viewDidLoad()

        updateStyle()

        title = localize("librarypickertitle")
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: localize("cancel"), style: .plain, target: self, action: #selector(close))


        searchController.searchResultsUpdater = self
        if #available(iOS 9.1, *) {
            searchController.obscuresBackgroundDuringPresentation = false
        }

        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            navigationItem.titleView = searchController.searchBar
        }

        searchController.searchBar.barTintColor = userPreferences.currentTheme.navigationTitle
        searchController.searchBar.tintColor = userPreferences.currentTheme.navigationTitle

        definesPresentationContext = true

        DispatchQueue(label: "Library list reader queue").async {
            var data = [LibrarySection]()
            guard let url = Bundle.main.url(forResource: self.libraryType.rawValue, withExtension: "json") else {
                return
            }
            guard let jsonData = try? JSONSerialization.jsonObject(with: Data(contentsOf: url), options: []) else {
                print("Bad JSON at url \(url). Aborting."); return
            }
            guard let array = jsonData as? Array<Array<Any>> else {
                print("[EasyHTML] Wrong JSON format at url \(url). Aborting."); return
            }

            let savedLibrariesUrlString = applicationPath + "/libraries/"
            let savedLibrariesUrl = URL(fileURLWithPath: savedLibrariesUrlString)

            if (!isDir(fileName: savedLibrariesUrlString)) {
                try? FileManager.default.createDirectory(atPath: savedLibrariesUrlString, withIntermediateDirectories: false, attributes: nil)
            }

            array.forEach {
                item in
                guard item.count == 2 else {
                    return
                }
                guard let sectionName = item[0] as? String else {
                    return
                }
                guard let libraryList = item[1] as? [[String]] else {
                    return
                }
                let sectionUrl = savedLibrariesUrl.appendingPathComponent(sectionName)
                let section = LibrarySection(name: sectionName)

                let sectionUrlString = sectionUrl.path

                if (!isDir(fileName: sectionUrlString)) {
                    mkDir(dirName: sectionUrlString)
                }

                libraryList.forEach {
                    library in
                    guard library.count == 2 else {
                        return
                    }
                    let libraryName = library[0]
                    let libraryPath = library[1]

                    let library = Library(name: libraryName, networkURL: libraryPath, isLoaded: false, section: section)

                    library.isLoaded = isFile(fileName: sectionUrl.appendingPathComponent(libraryName + library.ext).path)
                    section.libraries.append(library)
                }

                data.append(section)
            }

            DispatchQueue.main.sync {
                self.librarySections = data
                self.tableView.reloadData()
            }
        }
    }

    override internal func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        isFiltering() ? localize("findresults").replacingOccurrences(of: "#", with: "\(filteredLibraries.count)") : librarySections[section].name
    }

    @objc func close() {
        dismiss(animated: true, completion: nil)
    }

    internal override func numberOfSections(in tableView: UITableView) -> Int {
        isFiltering() ? 1 : librarySections.count
    }

    internal override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isFiltering() ? filteredLibraries.count : librarySections[section].libraries.count
    }

    internal override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        getCurrentLibrary(for: indexPath).isLoaded
    }

    internal override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        localize("delete")
    }

    internal override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            func delete(action: UIAlertAction) {
                let library = getCurrentLibrary(for: indexPath)

                var url = URL(fileURLWithPath: applicationPath + "/libraries/")
                url.appendPathComponent(library.section.name)
                url.appendPathComponent(library.name + library.ext)

                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    return
                }
                library.isLoaded = false

                let cell = tableView.cellForRow(at: indexPath) as! LibraryPickerTableViewCell
                cell.updateState()
                cell.downloadIndicatorView.indicatorLayer.setNeedsDisplay()
                cell.downloadIndicatorView.layer.setNeedsDisplay()
            }

            let deleteAlert = UIAlertController(title: localize("deleteconfirmforlibrary"), message: localize("deleteconfirmforlibrarydesc"), preferredStyle: UIAlertController.Style.actionSheet)
            deleteAlert.addAction(UIAlertAction(title: localize("delete"), style: UIAlertAction.Style.destructive, handler: delete))
            deleteAlert.addAction(UIAlertAction(title: localize("cancel"), style: UIAlertAction.Style.cancel, handler: nil))

            let cell = tableView.cellForRow(at: indexPath)!

            deleteAlert.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: cell.bounds.origin.x + cell.bounds.width, y: cell.bounds.origin.y + 20), size: CGSize(width: 50, height: 30))
            deleteAlert.popoverPresentationController?.sourceView = cell.contentView

            present(deleteAlert, animated: true, completion: nil)
        }
    }

    internal override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: LibraryPickerTableViewCell! = tableView.dequeueReusableCell(withIdentifier: "cell") as? LibraryPickerTableViewCell
        if cell == nil {

            cell = LibraryPickerTableViewCell(style: .subtitle, reuseIdentifier: "cell")
        }

        let library = getCurrentLibrary(for: indexPath)

        cell.downloadIndicatorView.indicatorLayer.library = library
        cell.textLabel!.text = library.name
        cell.textLabel!.textColor = userPreferences.currentTheme.cellTextColor
        cell.detailTextLabel!.textColor = userPreferences.currentTheme.secondaryTextColor

        cell.updateState()

        return cell
    }

    internal override func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        let library = getCurrentLibrary(for: indexPath)

        return library.isLoaded && !library.isLoading
    }

    deinit {
        LibraryPickerViewController.downloadManagers.forEach {
            manager in
            manager.session.invalidateAndCancel()
        }
        LibraryPickerViewController.downloadManagers = []
        LibraryPickerDownloadManager.id = 0
    }

}
