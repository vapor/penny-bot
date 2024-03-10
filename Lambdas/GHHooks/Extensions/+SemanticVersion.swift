import SwiftSemver

enum SemVerBump {
    case releaseStage
    case major
    case minor
    case patch
}

enum SemVerStage: String {
    case alpha
    case beta
    case rc
}

extension SemanticVersion {
    func next(_ bump: SemVerBump) -> SemanticVersion? {
        var version = self

        if version.prereleaseIdentifiers.isEmpty {
            switch bump {
            case .releaseStage:
                /// A bot shouldn't release a whole library.
                return nil
            case .patch:
                version.patch += 1
            case .minor:
                version.patch = 0
                version.minor += 1
            case .major:
                /// A bot shouldn't release a whole library.
                return nil
            }
        } else {
            guard version.prereleaseIdentifiers.count < 4 else {
                /// Shouldn't have more than 3 identifiers, otherwise unexpected by this code.
                return nil
            }
            /// At this point we are guaranteed 1/2/3 `prereleaseIdentifiers`.

            guard version.prereleaseIdentifiers[0].first?.isLetter ?? false else {
                /// Identifiers should be like `["alpha", "1"]`.
                /// First identifier should not be a number.
                return nil
            }

            guard version.prereleaseIdentifiers[1...].allSatisfy({ UInt($0) != nil }) else {
                /// Identifiers should be like `["alpha", "1"]`.
                /// All identifiers other than the first one should be a number.
                return nil
            }

            switch bump {
            case .releaseStage:
                let stage = SemVerStage(rawValue: version.prereleaseIdentifiers[0])
                switch stage {
                case .alpha:
                    version.prereleaseIdentifiers[0] = SemVerStage.beta.rawValue
                case .beta:
                    version.prereleaseIdentifiers[0] = SemVerStage.rc.rawValue
                case .rc:
                    /// A bot shouldn't release a whole library.
                    return nil
                default:
                    /// Don't know what is the next stage.
                    return nil
                }
            case .patch, .minor:
                if version.prereleaseIdentifiers.count == 1 {
                    /// Add "0" as the major identifier.
                    version.prereleaseIdentifiers.append("0")
                }
                /// At this point we are guaranteed 2 or 3 identifiers.

                if version.prereleaseIdentifiers.count == 2 {
                    /// Doesn't have any minor identifiers. We add it.
                    version.prereleaseIdentifiers.append("1")
                } else {
                    /// Already checked not-nil, but still trying to be safe.
                    guard let prev = Int(version.prereleaseIdentifiers.removeLast())
                    else { return nil }
                    version.prereleaseIdentifiers.append("\(prev + 1)")
                }
            case .major:
                if version.prereleaseIdentifiers.count == 1 {
                    /// Add "1" as the major identifier.
                    version.prereleaseIdentifiers.append("1")
                } else {
                    /// Already checked not-nil, but still trying to be safe.
                    guard let prev = Int(version.prereleaseIdentifiers[1])
                    else { return nil }
                    version.prereleaseIdentifiers[1] = "\(prev + 1)"
                }
            }
        }
        
        return version
    }
}

extension SemanticVersion {
    static func fromGitHubTag(
        _ tagName: String
    ) -> (prefix: String, version: SemanticVersion)? {
        var tagName = tagName
        var tagPrefix = ""
        /// For tags like "v1.0.0" which start with an alphabetical character.
        if tagName.first?.isNumber == false {
            tagPrefix = String(tagName.removeFirst())
        }
        guard let version = SemanticVersion(string: tagName) else {
            return nil
        }
        return (tagPrefix, version)
    }
}
