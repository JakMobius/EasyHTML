import UIKit

internal enum FileSourceType: Hashable, Codable {
    case unknown, local, ftp(server: FTPServer), dropbox, github(repo: String, commit: String);

    static func ==(a: FileSourceType, b: FileSourceType) -> Bool {
        switch (a, b) {
        case (.local, .local): return true
        case (.dropbox, .dropbox): return true
        case (.ftp(let server1), .ftp(let server2)): return server1 == server2
        case let (.github(a, b), .github(c, d)): return a == c && b == d
        default: return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case a
        case b
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .unknown:
            try container.encode(0, forKey: .type)
        case .local:
            try container.encode(1, forKey: .type)
        case .ftp(let server):
            let data = NSKeyedArchiver.archivedData(withRootObject: server)
            try container.encode(2, forKey: .type)
            try container.encode(data, forKey: .a)
        case .dropbox:
            try container.encode(3, forKey: .type)
        case .github(let repo, let commit):
            try container.encode(4, forKey: .type)
            try container.encode(repo, forKey: .a)
            try container.encode(commit, forKey: .b)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(Int.self, forKey: .type)

        switch type {
        case 1:
            self = .local
        case 2:
            let data = try container.decode(Data.self, forKey: .a)
            let server = NSKeyedUnarchiver.unarchiveObject(with: data) as! FTPServer

            self = .ftp(server: server)
        case 3:
            self = .dropbox
        case 4:
            let repo = try container.decode(String.self, forKey: .a)
            let commit = try container.decode(String.self, forKey: .b)

            self = .github(repo: repo, commit: commit)
        default:
            self = .unknown
        }
    }

    static func !=(a: FileSourceType, b: FileSourceType) -> Bool {
        !(a == b)
    }
}

