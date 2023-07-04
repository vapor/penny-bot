
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
}
