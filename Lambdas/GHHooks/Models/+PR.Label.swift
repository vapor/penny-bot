
extension PullRequest {
    var knownLabels: [KnownLabel] {
        self.labels.compactMap {
            KnownLabel(rawValue: $0.name)
        }
    }
}

enum KnownLabel: String {
    case semVerMajor = "semver-major"
    case semVerMinor = "semver-minor"
    case semVerPatch = "semver-patch"
    case release = "release"

    func toBump() -> SemVer.Bump {
        switch self {
        case .semVerMajor: return .major
        case .semVerMinor: return .minor
        case .semVerPatch: return .patch
        case .release: return .releaseStage
        }
    }
}
