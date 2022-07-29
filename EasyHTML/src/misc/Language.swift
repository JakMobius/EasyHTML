import Foundation

enum LocalizationTable {
    case general;
    case editor;
    case filedesc;
    case copyrights;
    case files;
    case ftp;
    case preferences;
    case github;
    
    var name: String! {
        switch self {
        case .general: return nil;
        case .editor: return "Editor";
        case .filedesc: return "FileDesc";
        case .copyrights: return "Copyrights";
        case .files: return "Files";
        case .ftp: return "FTP";
        case .preferences: return "Preferences";
        case .github: return "GitHub";
        }
    }
}

func localize(_ string: String, _ table: LocalizationTable = .general, default: String = "") -> String {
    return NSLocalizedString(string, tableName: table.name, bundle: userPreferences.bundle, value: `default`, comment: "")
}
