//
//  Version.swift
//  EasyHTML
//
//  Created by Артем on 28/10/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

internal class Version: Comparable {
    static func <(lhs: Version, rhs: Version) -> Bool {
        if (lhs.majorVersion < rhs.majorVersion) {
            return true
        }
        if (lhs.majorVersion > rhs.majorVersion) {
            return false
        }
        if (lhs.minorVersion < rhs.minorVersion) {
            return true
        }
        if (lhs.minorVersion > rhs.minorVersion) {
            return false
        }
        if (lhs.patch < rhs.patch) {
            return true
        }
        return false
    }

    static func ==(lhs: Version, rhs: Version) -> Bool {
        lhs.majorVersion == rhs.majorVersion &&
                rhs.minorVersion == rhs.minorVersion &&
                lhs.patch == rhs.patch
    }

    func isPriorTo(_ major: Int, _ minor: Int = 0, _ patch: Int = 0) -> Bool {
        if (majorVersion < major) {
            return true
        }
        if (majorVersion > major) {
            return false
        }
        if (minorVersion < minor) {
            return true
        }
        if (minorVersion > minor) {
            return false
        }
        if (self.patch <= patch) {
            return true
        }
        return false
    }

    static func >(lhs: Version, rhs: Version) -> Bool {
        if (lhs.majorVersion < rhs.majorVersion) {
            return false
        }
        if (lhs.majorVersion > rhs.majorVersion) {
            return true
        }
        if (lhs.minorVersion < rhs.minorVersion) {
            return false
        }
        if (lhs.minorVersion > rhs.minorVersion) {
            return true
        }
        if (lhs.patch <= rhs.patch) {
            return false
        }
        return true
    }

    var majorVersion: Int = 0;
    var minorVersion: Int = 0;
    var patch: Int = 0;

    init(majorVersion: Int, minorVersion: Int = 0, patch: Int = 0) {
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.patch = patch
    }

    init?(parsing string: String) {
        let parts = string.split(separator: ".")

        guard parts.count >= 1 else {
            return nil
        }
        guard let major = Int(parts[0]) else {
            return nil
        }
        majorVersion = major

        guard parts.count >= 2 else {
            return
        }
        guard let minor = Int(parts[1]) else {
            return
        }
        minorVersion = minor

        guard parts.count >= 3 else {
            return
        }
        guard let patch = Int(parts[2]) else {
            return
        }
        self.patch = patch
    }
}
