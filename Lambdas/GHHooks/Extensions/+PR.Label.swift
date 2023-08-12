import GitHubAPI

extension PullRequest {
    var knownLabels: [KnownLabel] {
        self.labels.compactMap {
            KnownLabel(rawValue: $0.name)
        }
    }
}

extension SimplePullRequest {
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
    case noReleaseNeeded = "no-release-needed"
    case translationUpdate = "translation-update"
    case noTranslationNeeded = "no-translation-needed"

    func toBump() -> SemVerBump? {
        switch self {
        case .semVerMajor: return .major
        case .semVerMinor: return .minor
        case .semVerPatch: return .patch
        case .release: return .releaseStage
        case .noReleaseNeeded, .translationUpdate, .noTranslationNeeded: return nil
        }
    }
}
