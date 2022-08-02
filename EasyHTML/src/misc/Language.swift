import Foundation

public class Language {
    let name: String
    let code: String
    let deviceCodes: [String]

    init(name: String, code: String, deviceCodes: [String] = []) {
        self.name = name
        self.code = code
        self.deviceCodes = deviceCodes
    }

    static let base = Language(name: "English", code: "Base", deviceCodes: [])
}

public let applicationLanguages = [
    Language.base,
    Language(name: "Русский", code: "ru", deviceCodes: ["ru"]),
    Language(name: "中文", code: "zh-Hans", deviceCodes: ["zh-CN", "zh-HK", "zh-MO", "zh-CHS", "zh-SG", "zh-TW", "zh-CHT", "zh-Hans"]),
    //Language(name: "Deutsch", code: "de")
]

enum LocalizationTable {
    case general;
    case editor;
    case fileDesc;
    case copyrights;
    case files;
    case ftp;
    case preferences;
    case github;

    var name: String! {
        switch self {
        case .general: return nil;
        case .editor: return "Editor";
        case .fileDesc: return "FileDesc";
        case .copyrights: return "Copyrights";
        case .files: return "Files";
        case .ftp: return "FTP";
        case .preferences: return "Preferences";
        case .github: return "GitHub";
        }
    }
}

func localize(_ string: String, _ table: LocalizationTable = .general, default: String = "") -> String {
    NSLocalizedString(string, tableName: table.name, bundle: userPreferences.bundle, value: `default`, comment: "")
}
