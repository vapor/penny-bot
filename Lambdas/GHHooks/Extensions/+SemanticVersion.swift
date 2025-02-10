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
    func next(_ bump: SemVerBump, forcePrerelease: Bool) -> SemanticVersion? {
        var version = self

        guard version.prereleaseIdentifiers.count < 3 else {
            /// Shouldn't have more than 2 identifiers, otherwise unexpected by this code.
            /// So something like `alpha.1.1` is unexpected, but `alpha.1` is fine.
            return nil
        }

        switch version.prereleaseIdentifiers.isEmpty {
        case true:
            switch forcePrerelease {
            case true:
                switch bump {
                case .releaseStage, .major:
                    /// A bot shouldn't release a whole new major version.
                    /// Major bump is unsupported in prereleases.
                    return nil
                case .patch, .minor:
                    /// Regardless, do a `alpha.1` release.
                    version.prereleaseIdentifiers = ["alpha", "1"]
                }
            case false:
                switch bump {
                case .releaseStage:
                    /// A bot shouldn't release a whole new major version.
                    return nil
                case .patch:
                    version.patch += 1
                case .minor:
                    version.patch = 0
                    version.minor += 1
                case .major:
                    /// A bot shouldn't release a whole new major version.
                    return nil
                }
            }
        case false:
            /// At this point we are guaranteed 1/2 `prereleaseIdentifiers`.

            guard version.prereleaseIdentifiers[0].allSatisfy(\.isLetter) else {
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
            case .releaseStage, .major:
                /// A bot shouldn't do a whole new major bump version.
                /// Major bump is unsupported in prereleases.
                return nil
            case .patch, .minor:
                switch version.prereleaseIdentifiers.count {
                case 1:
                    /// Add "1" as the major identifier (so like `alpha.1`).
                    version.prereleaseIdentifiers.append("1")
                case 2:
                    guard let prev = Int(version.prereleaseIdentifiers[1]) else { return nil }
                    version.prereleaseIdentifiers[1] = "\(prev + 1)"
                default:
                    fatalError(
                        "Already checked no more than 2 prerelease identifiers: \(version.prereleaseIdentifiers)"
                    )
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
