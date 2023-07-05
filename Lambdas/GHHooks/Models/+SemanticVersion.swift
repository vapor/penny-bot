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

        if version.prereleaseIdentifiers.isEmpty {
            switch bump {
            case .releaseStage:
                return nil
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
        } else {
            guard version.prereleaseIdentifiers.count < 4 else {
                /// Shouldn't have more than 3 identifiers, otherwise unexpected by this code.
                return nil
            }
            /// At this point we are guaranteed 1/2/3 `prereleaseIdentifiers`.

            guard !version.prereleaseIdentifiers[0].allSatisfy(\.isNumber) else {
                /// Identifiers should be like `["alpha", "1"]`.
                /// First identifier should not be a number.
                return nil
            }

            guard version.prereleaseIdentifiers[1...]
                .allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
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
                    /// Don't know what is the next stage.
                    return nil
                }
            case .patch, .minor:
                if version.prereleaseIdentifiers.count == 1 {
                    /// Add "0" as the major identifier.
                    version.prereleaseIdentifiers.append("0")
                }
                /// At this point we are guaranteed 2 or 3 identifiers.

                let lastIndex = version.prereleaseIdentifiers.count - 1
                if lastIndex == 1 {
                    /// Doesn't have any minor identifiers. We add it.
                    version.prereleaseIdentifiers.append("1")
                } else {
                    /// Already checked not-nil, but still trying to be safe.
                    guard let number = Int(version.prereleaseIdentifiers[lastIndex])
                    else { return nil }
                    version.prereleaseIdentifiers[lastIndex] = "\(number + 1)"
                }
            case .major:
                if version.prereleaseIdentifiers.count == 1 {
                    /// Add "1" as the major identifier.
                    version.prereleaseIdentifiers.append("1")
                } else {
                    /// Already checked not-nil, but still trying to be safe.
                    guard let number = Int(version.prereleaseIdentifiers[1])
                    else { return nil }
                    version.prereleaseIdentifiers[1] = "\(number + 1)"
                }
            }
        }
        
        return version
    }
}
