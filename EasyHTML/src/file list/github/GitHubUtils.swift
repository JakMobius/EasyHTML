//
//  GitHubUtils.swift
//  EasyHTML
//
//  Created by Артем on 29/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

enum GitHubError: LocalizedError {
    case rateLimitExceeded
    case unknown
    case notFound
    case accessDenied
    case message(message: String)
    
    var localizedDescription: String {
        switch self {
        case .rateLimitExceeded:
            return localize("errorratelimitexceeded", .github)
        case .unknown:
            return localize("errorunknown", .github)
        case .notFound:
            return localize("errornotfound", .github)
        case .accessDenied:
            return localize("erroraccessdenied", .github)
        case .message(let message):
            return message
        }
    }
    
    var errorDescription: String? {
        return localizedDescription
    }
}

struct GitHubUtils {
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        
        return formatter
    }()
    
    static func checkAPIResponse(response: HTTPURLResponse) -> Error? {
        if response.statusCode == 403 {
            let headers = response.allHeaderFields
            if let remaining = headers["X-RateLimit-Remaining"] as? String {
                if remaining == "0" {
                    return GitHubError.rateLimitExceeded
                } else {
                    return GitHubError.unknown
                }
            }
            return GitHubError.unknown
        }
        if response.statusCode == 404 {
            return GitHubError.notFound
        }
        return nil
    }
    
    static func avatarLoadingTask(url: URL, callback: @escaping (Data?) -> ()) -> URLSessionTask {
        return URLSession.shared.dataTask(with: url) {
            data, response, error in
            
            if error != nil {
                if (error! as NSError).code == NSURLErrorCancelled {
                    return
                }
                DispatchQueue.main.async {
                    callback(nil)
                }
                return
            }
            
            DispatchQueue.main.async {
                callback(data)
            }
        }
    }
    
    static let githubLanguageColors = [
        "1C Enterprise":0x814CCC,
        "ABAP":0xE8274B,
        "ActionScript":0x882B0F,
        "Ada":0x02f88c,
        "Agda":0x315665,
        "AGS Script":0xB9D9FF,
        "Alloy":0x64C800,
        "AMPL":0xE6EFBB,
        "AngelScript":0xC7D7DC,
        "ANTLR":0x9DC3FF,
        "API Blueprint":0x2ACCA8,
        "APL":0x5A8164,
        "AppleScript":0x101F1F,
        "Arc":0xaa2afe,
        "ASP":0x6a40fd,
        "AspectJ":0xa957b0,
        "Assembly":0x6E4C13,
        "Asymptote":0x4a0c0c,
        "ATS":0x1ac620,
        "AutoHotkey":0x6594b9,
        "AutoIt":0x1C3552,
        "Ballerina":0xFF5000,
        "Batchfile":0xC1F12E,
        "BlitzMax":0xcd6400,
        "Boo":0xd4bec1,
        "Brainfuck":0x2F2530,
        "C":0x555555,
        "C#":0x178600,
        "C++":0xf34b7d,
        "Ceylon":0xdfa535,
        "Chapel":0x8dc63f,
        "Cirru":0xccccff,
        "Clarion":0xdb901e,
        "Clean":0x3F85AF,
        "Click":0xE4E6F3,
        "Clojure":0xdb5855,
        "CoffeeScript":0x244776,
        "ColdFusion":0xed2cd6,
        "Common Lisp":0x3fb68b,
        "Common Workflow Language":0xB5314C,
        "Component Pascal":0xB0CE4E,
        "Crystal":0x000100,
        "CSS":0x563d7c,
        "Cuda":0x3A4E3A,
        "D":0xba595e,
        "Dart":0x00B4AB,
        "DataWeave":0x003a52,
        "DM":0x447265,
        "Dockerfile":0x384d54,
        "Dogescript":0xcca760,
        "Dylan":0x6c616e,
        "E":0xccce35,
        "eC":0x913960,
        "ECL":0x8a1267,
        "Eiffel":0x946d57,
        "Elixir":0x6e4a7e,
        "Elm":0x60B5CC,
        "Emacs Lisp":0xc065db,
        "EmberScript":0xFFF4F3,
        "EQ":0xa78649,
        "Erlang":0xB83998,
        "F#":0xb845fc,
        "F*":0x572e30,
        "Factor":0x636746,
        "Fancy":0x7b9db4,
        "Fantom":0x14253c,
        "FLUX":0x88ccff,
        "Forth":0x341708,
        "Fortran":0x4d41b1,
        "FreeMarker":0x0050b2,
        "Frege":0x00cafe,
        "Game Maker Language":0x71b417,
        "GDScript":0x355570,
        "Genie":0xfb855d,
        "Gherkin":0x5B2063,
        "Glyph":0xc1ac7f,
        "Gnuplot":0xf0a9f0,
        "Go":0x00ADD8,
        "Golo":0x88562A,
        "Gosu":0x82937f,
        "Grammatical Framework":0x79aa7a,
        "Groovy":0xe69f56,
        "Hack":0x878787,
        "Harbour":0x0e60e3,
        "Haskell":0x5e5086,
        "Haxe":0xdf7900,
        "HiveQL":0xdce200,
        "HTML":0xe34c26,
        "Hy":0x7790B2,
        "IDL":0xa3522f,
        "Idris":0xb30000,
        "Io":0xa9188d,
        "Ioke":0x078193,
        "Isabelle":0xFEFE00,
        "J":0x9EEDFF,
        "Java":0xb07219,
        "JavaScript":0xf1e05a,
        "Jolie":0x843179,
        "JSONiq":0x40d47e,
        "Jsonnet":0x0064bd,
        "Julia":0xa270ba,
        "Jupyter Notebook":0xDA5B0B,
        "Kotlin":0xF18E33,
        "KRL":0x28430A,
        "Lasso":0x999999,
        "Lex":0xDBCA00,
        "LFE":0x4C3023,
        "LiveScript":0x499886,
        "LLVM":0x185619,
        "LOLCODE":0xcc9900,
        "LookML":0x652B81,
        "LSL":0x3d9970,
        "Lua":0x000080,
        "Makefile":0x427819,
        "Mask":0xf97732,
        "MATLAB":0xe16737,
        "Max":0xc4a79c,
        "MAXScript":0x00a6a6,
        "mcfunction":0xE22837,
        "Mercury":0xff2b2b,
        "Meson":0x007800,
        "Metal":0x8f14e9,
        "Mirah":0xc7a938,
        "Modula-3":0x223388,
        "MQL4":0x62A8D6,
        "MQL5":0x4A76B8,
        "MTML":0xb7e1f4,
        "NCL":0x28431f,
        "Nearley":0x990000,
        "Nemerle":0x3d3c6e,
        "nesC":0x94B0C7,
        "NetLinx":0x0aa0ff,
        "NetLinx+ERB":0x747faa,
        "NetLogo":0xff6375,
        "NewLisp":0x87AED7,
        "Nextflow":0x3ac486,
        "Nim":0x37775b,
        "Nit":0x009917,
        "Nix":0x7e7eff,
        "Nu":0xc9df40,
        "Objective-C":0x438eff,
        "Objective-C++":0x6866fb,
        "Objective-J":0xff0c5a,
        "OCaml":0x3be133,
        "Omgrofl":0xcabbff,
        "ooc":0xb0b77e,
        "Opal":0xf7ede0,
        "Oxygene":0xcdd0e3,
        "Oz":0xfab738,
        "P4":0x7055b5,
        "Pan":0xcc0000,
        "Papyrus":0x6600cc,
        "Parrot":0xf3ca0a,
        "Pascal":0xE3F171,
        "Pawn":0xdbb284,
        "Pep8":0xC76F5B,
        "Perl":0x0298c3,
        "Perl 6":0x0000fb,
        "PHP":0x4F5D95,
        "PigLatin":0xfcd7de,
        "Pike":0x005390,
        "PLSQL":0xdad8d8,
        "PogoScript":0xd80074,
        "PostScript":0xda291c,
        "PowerBuilder":0x8f0f8d,
        "PowerShell":0x012456,
        "Processing":0x0096D8,
        "Prolog":0x74283c,
        "Propeller Spin":0x7fa2a7,
        "Puppet":0x302B6D,
        "PureBasic":0x5a6986,
        "PureScript":0x1D222D,
        "Python":0x3572A5,
        "q":0x0040cd,
        "QML":0x44a51c,
        "Quake":0x882233,
        "R":0x198CE7,
        "Racket":0x3c5caa,
        "Ragel":0x9d5200,
        "RAML":0x77d9fb,
        "Rascal":0xfffaa0,
        "Rebol":0x358a5b,
        "Red":0xf50000,
        "Ren'Py":0xff7f7f,
        "Ring":0x2D54CB,
        "Roff":0xecdebe,
        "Rouge":0xcc0088,
        "Ruby":0x701516,
        "RUNOFF":0x665a4e,
        "Rust":0xdea584,
        "SaltStack":0x646464,
        "SAS":0xB34936,
        "Scala":0xc22d40,
        "Scheme":0x1e4aec,
        "sed":0x64b970,
        "Self":0x0579aa,
        "Shell":0x89e051,
        "Shen":0x120F14,
        "Slash":0x007eff,
        "Slice":0x003fa2,
        "Smalltalk":0x596706,
        "Solidity":0xAA6746,
        "SourcePawn":0x5c7611,
        "SQF":0x3F3F3F,
        "Squirrel":0x800000,
        "SRecode Template":0x348a34,
        "Stan":0xb2011d,
        "Standard ML":0xdc566d,
        "SuperCollider":0x46390b,
        "Swift":0xffac45,
        "SystemVerilog":0xDAE1C2,
        "Tcl":0xe4cc98,
        "Terra":0x00004c,
        "TeX":0x3D6117,
        "TI Program":0xA0AA87,
        "Turing":0xcf142b,
        "TypeScript":0x2b7489,
        "UnrealScript":0xa54c4d,
        "Vala":0xfbe5cd,
        "VCL":0x148AA8,
        "Verilog":0xb2b7f8,
        "VHDL":0xadb2cb,
        "Vim script":0x199f4b,
        "Visual Basic":0x945db7,
        "Volt":0x1F1F1F,
        "Vue":0x2c3e50,
        "wdl":0x42f1f4,
        "WebAssembly":0x04133b,
        "wisp":0x7582D1,
        "X10":0x4B6BEF,
        "xBase":0x403a40,
        "XC":0x99DA07,
        "XQuery":0x5232e7,
        "XSLT":0xEB8CEB,
        "Yacc":0x4B6C4B,
        "YARA":0x220000,
        "YASnippet":0x32AB90,
        "ZAP":0x0d665e,
        "Zephir":0x118f9e,
        "Zig":0xec915c,
        "ZIL":0xdc75e5
    ]
    
    static func colorFor(language: String) -> UIColor? {
        guard let n = githubLanguageColors[language] else { return nil }
        
        let r = CGFloat((n & 0xff0000) >> 16)
        let g = CGFloat((n & 0x00ff00) >> 8)
        let b = CGFloat(n & 0x0000ff)
        
        return UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1.0)
    }

    
    static var userImageCache = [String : NSData]()
    static var tintLightColor = UIColor(red: 0.011, green: 0.4, blue: 0.839, alpha: 1)
    static var tintDarkColor = UIColor(red: 0.988, green: 0.6, blue: 0.1607, alpha: 1)
    static var currentTintColor: UIColor {
        if userPreferences.currentTheme.isDark {
            return GitHubUtils.tintDarkColor
        } else {
            return GitHubUtils.tintLightColor
        }
    }
}
