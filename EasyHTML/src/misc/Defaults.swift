//
//  Defaults.swift
//  EasyHTML
//
//  Created by Артем on 22.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import Foundation

private extension String {
    func modified() -> String {
        if _testing {
            return "test-" + self;
        }

        return self;
    }
}

class Defaults {
    internal static var defaults = UserDefaults.standard;

    internal static func object(forKey: String, def: Any? = nil) -> Any? {
        let v = defaults.object(forKey: forKey.modified())
        return v == nil ? def : v
    }

    internal static func int(forKey: String, def: Int = 0) -> Int {
        (object(forKey: forKey.modified(), def: def) as? Int) ?? def
    }

    internal static func int8(forKey: String, def: Int8 = 0) -> Int8 {
        (object(forKey: forKey.modified(), def: def) as? Int8) ?? def
    }

    internal static func float(forKey: String, def: Float = 0) -> Float {
        (object(forKey: forKey.modified(), def: def) as? Float) ?? def
    }

    internal static func string(forKey: String, def: String = "") -> String {
        (object(forKey: forKey.modified(), def: def) as? String) ?? def
    }

    internal static func bool(forKey: String, def: Bool = false) -> Bool {
        (object(forKey: forKey.modified(), def: def) as? Bool) ?? def
    }

    internal static func data(forKey: String) -> Data? {
        object(forKey: forKey.modified()) as? Data
    }

    internal static func set(_ value: Any?, forKey key: String) {
        defaults.setValue(value, forKey: key.modified())
    }

    internal static func removeObject(forKey: String) {
        defaults.removeObject(forKey: forKey.modified())
    }

    internal static func wipeTestingDefaults() {
        if (_testing) {
            let map = defaults.dictionaryRepresentation()

            for i in map {
                if i.key.starts(with: "test-") {
                    defaults.removeObject(forKey: i.key)
                }
            }
        }
    }
}
