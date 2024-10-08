import GitHubAPI

extension PullRequest {

    enum KnownLabel: String {
        case semVerMajor = "semver-major"
        case semVerMinor = "semver-minor"
        case semVerPatch = "semver-patch"
        case semVerNoOp = "semver-noop"
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
            case .semVerNoOp, .noReleaseNeeded, .translationUpdate, .noTranslationNeeded: return nil
            }
        }
    }

    var knownLabels: [KnownLabel] {
        self.labels.compactMap {
            KnownLabel(rawValue: $0.name)
        }
    }
}

extension SimplePullRequest {
    var knownLabels: [PullRequest.KnownLabel] {
        self.labels.compactMap {
            PullRequest.KnownLabel(rawValue: $0.name)
        }
    }
}
