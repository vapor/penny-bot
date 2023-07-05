import SwiftSemver

enum SemVerBump {
    case releaseStage
    case major
    case minor
    case patch
}

extension SemanticVersion {
    func next(_ bump: SemVerBump) -> SemanticVersion? {
        var version = self
        if !version.prereleaseIdentifiers.isEmpty {
            guard version.prereleaseIdentifiers.count < 4 else {
                /// Shouldn't have more than 3 identifiers, otherwise unexpected by this code.
                return nil
            }
            /// At this point we are guaranteed 1/2/3 identifiers.

            guard !version.prereleaseIdentifiers[0].allSatisfy(\.isNumber) else {
                /// Identifiers should be like `["alpha", "1"]`.
                /// First identifier should not be a number.
                return nil
            }

            guard version.prereleaseIdentifiers[1...].allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
                /// Identifiers should be like `["alpha", "1"]`.
                /// All identifiers other than the first one should be a number.
                return nil
            }
            switch bump {
            case .releaseStage:
                switch version.prereleaseIdentifiers[0] {
                case "alpha":
                    version.prereleaseIdentifiers[0] = "beta"
                case "beta":
                    version.prereleaseIdentifiers[0] = "rc"
                case "rc":
                    /// A bot shouldn't release a whole library.
                    return nil
                default:
                    /// Don't know what is the next stage is.
                    return nil
                }
            case .patch, .minor:
                if version.prereleaseIdentifiers.count == 1 {
                    /// Add "0" as a major identifier
                    version.prereleaseIdentifiers.append("0")
                }

                /// At this point we are guaranteed 2 or 3 identifiers

                let lastIndex = version.prereleaseIdentifiers.count - 1
                if lastIndex == 1 {
                    /// Don't have any minor identifiers. We add it.
                    version.prereleaseIdentifiers.append("1")
                } else {
                    guard let number = Int(version.prereleaseIdentifiers[lastIndex])
                    else { return nil }
                    version.prereleaseIdentifiers[lastIndex] = "\(number + 1)"
                }
            case .major:
                if version.prereleaseIdentifiers.count == 1 {
                    /// Add "1" as the major identifier
                    version.prereleaseIdentifiers.append("1")
                } else {
                    /// Already checked not-nil, but still trying to be safe.
                    guard let number = Int(version.prereleaseIdentifiers[1])
                    else { return nil }
                    version.prereleaseIdentifiers[1] = "\(number + 1)"
                }
            }
        } else {
            switch bump {
            case .releaseStage:
                break
            case .patch:
                version.patch += 1
            case .minor:
                version.patch = 0
                version.minor += 1
            case .major:
                version.patch = 0
                version.minor = 0
                version.major += 1
            }
        }

        return version

//        var version = self
//        if var prerelease = version.prerelease {
//            let p: Prerelease?
//            switch bump {
//            case .releaseStage:
//                p = prerelease.nextReleaseStage
//            case .patch, .minor:
//                if let existing = prerelease.minor {
//                    p = .init(name: prerelease.name, major: prerelease.major, minor: existing + 1)
//                } else {
//                    p = .init(name: prerelease.name, major: prerelease.major, minor: 1)
//                }
//            case .major:
//                prerelease.minor = nil
//                if let existing = prerelease.major {
//                    p = .init(name: prerelease.name, major: existing + 1, minor: nil)
//                } else {
//                    p = .init(name: prerelease.name, major: 1, minor: nil)
//                }
//            }
//            version.prerelease = p
//        } else {
//            switch bump {
//            case .releaseStage:
//                break
//            case .patch:
//                version.patch += 1
//            case .minor:
//                version.patch = 0
//                version.minor += 1
//            case .major:
//                version.patch = 0
//                version.minor = 0
//                version.major += 1
//            }
//        }
//        return version
    }
}

//struct SemVer {
//
//    struct Prerelease {
//        enum Identifier: String {
//            case alpha
//            case beta
//            case rc
//        }
//
//        var name: String
//        var major: Int?
//        var minor: Int?
//
//        var nextReleaseStage: Self? {
//            guard let identifier = Identifier(rawValue: self.name) else {
//                return nil
//            }
//            switch identifier {
//            case .alpha: return .init(name: Identifier.beta.rawValue, major: nil, minor: nil)
//            case .beta: return .init(name: Identifier.rc.rawValue, major: nil, minor: nil)
//            case .rc: return nil
//            }
//        }
//    }
//
//    var major: Int
//    var minor: Int
//    var patch: Int
//    var prerelease: Prerelease?
//
//    init? (string: String) {
//        // 1.2.3-beta.4.5
//        let parts = string.split(separator: "-")
//        switch parts.count {
//        case 1, 2:
//            // 1.2.3
//            let version = parts[0].split(separator: ".")
//            switch version.count {
//            case 3:
//                guard let major = Int(version[0]) else {
//                    return nil
//                }
//                self.major = major
//                guard let minor = Int(version[1]) else {
//                    return nil
//                }
//                self.minor = minor
//                guard let patch = Int(version[2]) else {
//                    return nil
//                }
//                self.patch = patch
//            default:
//                return nil
//            }
//            switch parts.count {
//            case 1:
//                self.prerelease = nil
//            case 2:
//                let prerelease = parts[1].split(separator: ".")
//                switch prerelease.count {
//                case 1, 2, 3:
//                    let name = String(prerelease[0])
//                    let major: Int?
//                    let minor: Int?
//                    switch prerelease.count {
//                    case 2, 3:
//                        guard let m = Int(prerelease[1]) else {
//                            return nil
//                        }
//                        major = m
//                        switch prerelease.count {
//                        case 3:
//                            guard let mi = Int(prerelease[2]) else {
//                                return nil
//                            }
//                            minor = mi
//                        default:
//                            minor = nil
//                        }
//                    default:
//                        major = nil
//                        minor = nil
//                    }
//                    self.prerelease = Prerelease(
//                        name: name,
//                        major: major,
//                        minor: minor
//                    )
//                default:
//                    return nil
//                }
//            default:
//                return nil
//            }
//        default:
//            return nil
//        }
//    }
//}
//
//extension SemVer.Prerelease: Comparable {
//    static func < (lhs: SemVer.Prerelease, rhs: SemVer.Prerelease) -> Bool {
//        lhs.name < rhs.name
//        && (lhs.major ?? 0) < (rhs.major ?? 0)
//        && (lhs.minor ?? 0) < (rhs.minor ?? 0)
//    }
//}
//
//extension SemVer: Comparable {
//    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
//        if lhs.major < rhs.major {
//            return true
//        } else if lhs.major == rhs.major && lhs.minor < rhs.minor {
//            return true
//        } else if lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch < rhs.patch {
//            return true
//        } else if let lpr = lhs.prerelease,
//                  lhs.major == rhs.major, lhs.minor == rhs.minor, lhs.patch == rhs.patch
//        {
//            if let rpr = rhs.prerelease {
//                return lpr < rpr
//            } else {
//                return true
//            }
//        } else {
//            return false
//        }
//    }
//
//    static func == (lhs: SemVer, rhs: SemVer) -> Bool {
//        lhs.major == rhs.major
//        && lhs.minor == rhs.minor
//        && lhs.patch == rhs.patch
//        && lhs.prerelease == rhs.prerelease
//    }
//}
//
//extension SemVer: CustomStringConvertible {
//    var description: String {
//        var description = "\(self.major).\(self.minor).\(self.patch)"
//        if let prerelease = self.prerelease {
//            description += "-\(prerelease.name)"
//            if let major = prerelease.major {
//                description += ".\(major)"
//            }
//            if let minor = prerelease.minor {
//                description += ".\(minor)"
//            }
//        }
//        return description
//    }
//}
