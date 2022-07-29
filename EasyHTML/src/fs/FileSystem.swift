import Foundation
import UIKit
import MobileCoreServices

let applicationPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]

@discardableResult func mkDir(dirName: String) -> Bool {
    do {
        try FileManager.default.createDirectory(atPath: dirName, withIntermediateDirectories: false, attributes: nil)
        return true
    } catch {
        return false
    }
}

func listDir(dirName: String) -> [String] {
    do {
        let files = try FileManager.default.contentsOfDirectory(atPath: dirName)

        return files
    } catch {
        return [String]()
    }
}

func fileOrFolderExist(name: String) -> Bool {
    FileManager.default.fileExists(atPath: name)
}

func isFile(fileName: String) -> Bool {
    var isDir: ObjCBool = false
    if (FileManager.default.fileExists(atPath: fileName, isDirectory: &isDir) && !isDir.boolValue) {
        return true
    }
    return false
}

func isDir(fileName: String) -> Bool {
    var isDir: ObjCBool = false
    if (FileManager.default.fileExists(atPath: fileName, isDirectory: &isDir) && isDir.boolValue) {
        return true
    }
    return false
}

func bundleFileData(name: String, ext: String) -> Data? {
    if let url = Bundle.main.url(forResource: name, withExtension: ext) {
        return try? Data(contentsOf: url)
    }
    return nil
}

func readBundleFile(name: String, ext: String) -> String? {
    if let path = Bundle.main.url(forResource: name, withExtension: ext)?.path {
        return try? String(contentsOfFile: path)
    }
    return nil
}

func getFileAttributes(fileName: String) -> NSDictionary {
    do {
        let attr = try FileManager.default.attributesOfItem(atPath: fileName)
        return attr as NSDictionary
    } catch {
        print(error)
        return NSDictionary()
    }

}

func getFolderSize(at path: String) -> UInt64 {

    let url = NSURL(fileURLWithPath: path)

    if isDir(fileName: path) {

        let files = listDir(dirName: path)
        var folderFileSizeInBytes: UInt64 = 0
        for file in files {

            let filepath = url.appendingPathComponent(file)?.path;
            if isDir(fileName: filepath!) {
                folderFileSizeInBytes += getFolderSize(at: filepath!)
            } else {
                folderFileSizeInBytes += getFileAttributes(fileName: path + "/" + file).fileSize()
            }
        }

        return folderFileSizeInBytes
    }

    return 0
}

func getFilePreviewImageByExtension(_ ext: String, inverted: Bool = false) -> UIImage {
    let ext = ext.lowercased()
    switch ext {
    case "html", "htm", "xml":
        return inverted ? FilePreviewImages.xmlImageInverted : FilePreviewImages.xmlImage
    case "js", "css", "java", "py", "scss", "php", "scala", "c", "cpp", "m", "cs", "swift", "pas", "lua", "json", "svg", "fs", "fsx", "for", "f77", "ftn", "ocaml":
        return inverted ? FilePreviewImages.codeImageInverted : FilePreviewImages.codeImage
    case "txt":
        return inverted ? FilePreviewImages.txtImageInverted : FilePreviewImages.txtImage
    case "zip":
        return inverted ? FilePreviewImages.zipImageInverted : FilePreviewImages.zipImage
    case "md":
        return inverted ? FilePreviewImages.mdImageInverted : FilePreviewImages.mdImage
    default:
        if (Editor.imageExtensions.contains(ext)) {
            return inverted ? FilePreviewImages.photoImageInverted : FilePreviewImages.photoImage
        }

        return inverted ? FilePreviewImages.fileImageInverted : FilePreviewImages.fileImage
    }
}

func getFileExtensionFromString(fileName: String) -> String {
    let array = fileName.split(separator: ".").map(String.init)

    if (array.count > 1) {
        return array.last!.lowercased()
    }
    return ""
}

func getFileTemplateDataFromExtension(ext: String) -> Data! {
    let data: Data?

    if ext == "" {
        data = nil
    } else {
        data = bundleFileData(name: ext, ext: "exmp")
    }

    return data
}

func getFileNameFromString(fileName: String) -> String {
    var components = fileName.split(separator: ".").map(String.init)
    if components.count > 1 {
        components.removeLast()
        return components.joined(separator: ".")
    }

    return fileName
}

func getFileNameAndExtensionFromString(fileName: String) -> [String] {
    var fileName = " " + fileName
    var components = fileName.split(separator: ".").map(String.init)
    if components.count > 1 {
        let ext = components.last?.lowercased() ?? ""
        components.removeLast()

        var joined = components.joined(separator: ".")
        joined.remove(at: joined.startIndex)

        return [joined, ext]
    }

    fileName.remove(at: fileName.startIndex)

    return [fileName, ""]
}

func listDirWithSorting(path: String) -> [String] {
    var path = path

    if (!path.hasSuffix("/")) {
        path = path + "/"
    }

    let filesWithoutSorting = listDir(dirName: path)

    if (userPreferences.sortingType == .none) {
        return filesWithoutSorting
    }
    if (userPreferences.sortingType == .byName) {
        return filesWithoutSorting.sorted {
            getFileNameFromString(fileName: $0) < getFileNameFromString(fileName: $1)
        }
    }
    if (userPreferences.sortingType == .byCreationDate) {

        var fileCreationDates = [String: TimeInterval]()

        for file in filesWithoutSorting {
            fileCreationDates[file] = getFileAttributes(fileName: path + file).fileCreationDate()!.timeIntervalSince1970
        }

        return filesWithoutSorting.sorted {
            (file1, file2) in

            let date1 = fileCreationDates[file1]!
            let date2 = fileCreationDates[file2]!

            return date1 > date2
        }
    }
    if (userPreferences.sortingType == .byLastEditingDate) {

        var fileEditingDates = [String: TimeInterval]()

        for file in filesWithoutSorting {
            fileEditingDates[file] = getFileAttributes(fileName: path + file).fileModificationDate()!.timeIntervalSince1970
        }

        return filesWithoutSorting.sorted {
            (file1, file2) in

            let date1 = fileEditingDates[file1]!
            let date2 = fileEditingDates[file2]!

            return date1 > date2
        }
    }
    if (userPreferences.sortingType == .byType) {

        var isDirectory = [String: Bool]()

        for file in filesWithoutSorting {
            isDirectory[file] = isDir(fileName: path + file)
        }

        return filesWithoutSorting.sorted {
            (file1, file2) in

            let isDir1 = isDirectory[file1]!
            let isDir2 = isDirectory[file2]!

            if (isDir1) {
                return isDir2
            }
            if (isDir2) {
                return !isDir1
            }

            return getFileExtensionFromString(fileName: file1) < getFileExtensionFromString(fileName: file2)
        }
    }

    return filesWithoutSorting
}

func getFileItemSize(at path: String) -> UInt64 {
    var isDir: ObjCBool = false;
    FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

    if isDir.boolValue {
        return getFolderSize(at: path)
    } else {
        return getFileAttributes(fileName: path).fileSize()
    }
}

func getLocalizedFileItemSize(at path: String) -> String {
    var isDir: ObjCBool = false;
    FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

    var size: UInt64

    if (isDir.boolValue) {
        size = getFolderSize(at: path)
    } else {
        size = getFileAttributes(fileName: path).fileSize()
    }

    if (size == 0 && isDir.boolValue) {
        return localize("emptyfolder", .files)
    } else {
        return getLocalizedFileSize(bytes: Int64(size))
    }
}

func getLocalizedFileSize(bytes: Int64, fraction: Int = 0, shouldCheckAdditionalCases: Bool = true) -> String {
    precondition(fraction >= 0, "getLocalizedFileSize(bytes: Int64, fraction: Int): Fraction argument (\(fraction)) cannot be less than zero")
    if (bytes < 0) {
        return localize("file")
    }
    if (bytes == 0 && shouldCheckAdditionalCases) {
        return localize("emptyfile")
    }

    func checkMultiplier(_ multiplier: Int64, _ string: String) -> String? {
        if (bytes >= multiplier) {

            var powerAmplifier = 1.0
            var multiplier = Double(multiplier)
            let bytes = Double(bytes)

            for _ in 0..<fraction {
                if (multiplier <= 10) {
                    break
                }
                multiplier /= 10.0
                powerAmplifier *= 10.0
            }
            if (fraction == 0) {
                return "\(Int(round(bytes / multiplier) / powerAmplifier)) \(localize(string))"
            }
            return "\(round(bytes / multiplier) / powerAmplifier) \(localize(string))"
        }
        return nil
    }

    var result: String?

    result = checkMultiplier(1073741824, "gb"); if let result = result {
        return result
    }
    result = checkMultiplier(1048576, "mb"); if let result = result {
        return result
    }
    result = checkMultiplier(1024, "kb"); if let result = result {
        return result
    }
    result = checkMultiplier(1, "b"); if let result = result {
        return result
    }

    return ""
}
