import Foundation
import SwiftyDropbox

enum GeneralizedCallError {
    case internalServerError(Int, String?, String?)
    case badInputError(String?, String?)
    case rateLimitError(Auth.RateLimitError, String?, String?, String?)
    case httpError(Int?, String?, String?)
    case authError(Auth.AuthError, String?, String?, String?)
    case accessError(Auth.AccessError, String?, String?, String?)
    case routeError(Any, String?, String?, String?)
    case clientError(Error?)

    internal var localizedDescription: String {
        switch self {
        case .internalServerError(let code, let userMessage, _):
            var message = localize("internalservererror", .files) + " (\(code))"

            if let userMessage = userMessage, !userMessage.isEmpty {
                message += ": " + userMessage
            }

            return message
        case .badInputError(let userMessage, _):
            var message = localize("badinputerror", .files)

            if let userMessage = userMessage, !userMessage.isEmpty {
                message += ": " + userMessage
            }

            return message
        case .authError(_, let userMessage, _, _):
            var message = localize("autherror", .files)

            if let userMessage = userMessage, !userMessage.isEmpty {
                message += ": " + userMessage
            }

            return message
        case .accessError(_, let userMessage, _, _):
            var message = localize("accesserror", .files)

            if let userMessage = userMessage, !userMessage.isEmpty {
                message += ": " + userMessage
            }

            return message
        case .rateLimitError(_, let userMessage, _, _):
            var message = localize("ratelimiterror", .files)

            if let userMessage = userMessage, !userMessage.isEmpty {
                message += ": " + userMessage
            }

            return message
        case .httpError(let code, let userMessage, _):
            var message = localize("httperror", .files)

            if let code = code {
                message += " (\(code)"
            }
            if let userMessage = userMessage, !userMessage.isEmpty {
                message += ": " + userMessage
            }

            return message
        case .clientError(let error):

            if let error = error {
                return error.localizedDescription
            } else {
                return localize("unknownerror")
            }

        case .routeError(let unboxed, _, _, _):

            if let error = unboxed as? Files.DeleteError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.WriteError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.LookupError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.SearchError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.UploadError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.PreviewError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.RestoreError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.DownloadError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.ThumbnailError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.RelocationError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.UploadSessionFinishError {
                return error.localizedDescription
            } else if let error = unboxed as? Files.CreateFolderError {
                return error.localizedDescription
            }
            return localize("unknownerror")
        }
    }
}

extension CallError {

    internal var generalized: GeneralizedCallError {
        switch self {
        case let .internalServerError(a, b, c):
            return .internalServerError(a, b, c)
        case let .badInputError(a, b):
            return .badInputError(a, b)
        case let .authError(a, b, c, d):
            return .authError(a, b, c, d)
        case let .accessError(a, b, c, d):
            return .accessError(a, b, c, d)
        case let .rateLimitError(a, b, c, d):
            return .rateLimitError(a, b, c, d)
        case let .httpError(a, b, c):
            return .httpError(a, b, c)
        case let .clientError(a):
            return .clientError(a)
        case let .routeError(a, b, c, d):
            return .routeError(a.unboxed, b, c, d)
        }
    }
}

extension Files.WriteConflictError {
    internal var localizedDescription: String {
        get {
            switch self {
            case .file, .fileAncestor: return localize("errorfileonpath", .files)
            case .folder: return localize("errorfolderonpath", .files)
            case .other: return localize("unknownerror")
            }
        }
    }
}

extension Files.WriteError {
    internal var localizedDescription: String {
        get {
            switch self {
            case .conflict(let conflict): return conflict.localizedDescription
            case .disallowedName: return localize("errordisallowedname", .files)
            case .insufficientSpace: return localize("errorinsufficientspace", .files)
            case .malformedPath(_): return localize("errormalformedpath", .files)
            case .noWritePermission: return localize("errornowritepermission", .files)
            case .other: return localize("unknownerror")
            case .teamFolder: return localize("errorteamfolder", .files)
            case .tooManyWriteOperations: return localize("errortoomanywriteoperations", .files)
            }
        }
    }
}

extension Files.DeleteError {
    internal var localizedDescription: String {
        switch self {
        case .other: return localize("unknownerror")
        case .pathLookup(let lookupError): return lookupError.localizedDescription
        case .pathWrite(let writeError): return writeError.localizedDescription
        case .tooManyFiles: return localize("errortoomanyfiles", .files)
        case .tooManyWriteOperations: return localize("errortoomanywriteoperations", .files)
        }
    }
}

extension Files.SearchError {
    internal var localizedDescription: String {
        switch self {
        case .other: return localize("unknownerror")
        case .path(let lookupError): return lookupError.localizedDescription
        }
    }
}

extension Files.UploadError {
    internal var localizedDescription: String {
        switch self {
        case .other, .propertiesError(_): return localize("unknownerror")
        case .path(let uploadWriteFailed): return uploadWriteFailed.reason.localizedDescription
        }
    }
}

extension Files.PreviewError {
    internal var localizedDescription: String {
        switch self {
        case .inProgress: return localize("errorpreviewinprogress", .files)
        case .path(let lookupError): return lookupError.localizedDescription
        case .unsupportedContent: return localize("errorpreviewunsupportedcontent", .files)
        case .unsupportedExtension: return localize("errorpreviewunsupportedextension", .files)
        }
    }
}

extension Files.RestoreError {
    internal var localizedDescription: String {
        switch self {
        case .invalidRevision: return localize("errorrestoreinvalidrevision", .files)
        case .other: return localize("unknownerror")
        case .pathLookup(let lookupError): return lookupError.localizedDescription
        case .pathWrite(let writeError): return writeError.localizedDescription
        }
    }
}

extension Files.DownloadError {
    internal var localizedDescription: String {
        get {
            switch self {
            case .other: return localize("unknownerror")
            case .path(let lookupError): return lookupError.localizedDescription
            }
        }
    }
}

extension Files.ThumbnailError {
    internal var localizedDescription: String {
        get {
            switch self {
            case .conversionError: return localize("errorthumbnailconversion", .files)
            case .path(let lookupError): return lookupError.localizedDescription
            case .unsupportedImage: return localize("errorthumbnailunsupportedimage", .files)
            case .unsupportedExtension: return localize("errorthumbnailunsupportedextension", .files)
            }
        }
    }
}

extension Files.CreateFolderError {
    internal var localizedDescription: String {
        get {
            switch self {
            case .path(_): return localize("errormalformedpath", .files)
            }
        }
    }
}

extension Files.RelocationError {
    internal var localizedDescription: String {
        get {
            switch self {
            case .internalError: return localize("internalservererror", .files)
            case .fromLookup(let lookupError): return localize("errorrelocationfromlookup", .files) + ": " + lookupError.localizedDescription
                /// An unspecified error.
            case .fromWrite(let writeError): return localize("errorrelocationfromwrite", .files) + ": " + writeError.localizedDescription
                /// An unspecified error.
            case .to(let writeError): return localize("errorrelocationtowrite", .files) + ": " + writeError.localizedDescription
                /// Shared folders can't be copied.
            case .cantCopySharedFolder: return localize("errorcantcopysharedfolder", .files)
                /// Your move operation would result in nested shared folders.  This is not allowed.
            case .cantNestSharedFolder: return localize("errorcantnestsharedfolder", .files)
                /// You cannot move a folder into itself.
            case .cantMoveFolderIntoItself: return localize("errorcantmovefolderintoitself", .files)
                /// The operation would involve more than 10,000 files and folders.
            case .tooManyFiles: return localize("errorrelocationtoomanyfiles", .files)
                /// There are duplicated/nested paths among fromPath in RelocationArg and toPath in RelocationArg.
            case .duplicatedOrNestedPaths: return localize("errorduplicatedornestedpaths", .files)
                /// Your move operation would result in an ownership transfer. You may reissue the request with the field
                /// allowOwnershipTransfer in RelocationArg to true.
            case .cantTransferOwnership: return ""
                /// The current user does not have enough space to move or copy the files.
            case .insufficientQuota: return localize("errorinsufficientspace", .files)
                /// An unspecified error.
            case .other: return localize("unknownerror")
            }
        }
    }
}

extension Files.UploadSessionFinishError {
    internal var localizedDescription: String {
        get {
            switch self {
            case .lookupFailed(let error):
                return error.localizedDescription
            case .path(let error):
                return error.localizedDescription
            case .tooManyWriteOperations:
                return localize("errortoomanywriteoperations", .files)
            default:
                return localize("unknownerror")
            }
        }
    }
}

extension Files.UploadSessionLookupError {
    internal var localizedDescription: String {
        get {
            switch self {

            case .notFound:
                return localize("errornotfound", .files)
            default:
                return localize("unknownerror")
            }
        }
    }
}

internal struct DropboxError: LocalizedError {
    var callError: GeneralizedCallError

    var errorDescription: String? {
        localizedDescription
    }

    var localizedDescription: String {
        callError.localizedDescription
    }

    internal init?(error: GeneralizedCallError?) {
        if let error = error {
            callError = error
        } else {
            return nil
        }
    }
}

extension Files.LookupError {
    internal var localizedDescription: String {
        get {
            switch self {
            case .malformedPath(_): return localize("errormalformedpath", .files)
            case .notFile: return localize("errornotfile", .files)
            case .notFolder: return localize("errornotfolder", .files)
            case .notFound: return localize("errornotfound", .files)
            case .restrictedContent: return localize("errorrestrictedcontent", .files)
            case .other: return localize("unknownerror")
            }
        }
    }
}
