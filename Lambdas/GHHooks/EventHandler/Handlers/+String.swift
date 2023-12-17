import GitHubAPI

extension String? {
    /// Usage example: `context.event.ref.extractHeadBranchFromRef()`
    func extractHeadBranchFromRef() -> Substring? {
        guard let ref = self, ref.hasPrefix("refs/heads/") else {
            return nil
        }
        return ref.dropFirst(11)
    }
}

extension StringProtocol where SubSequence == Substring {
    func isPrimaryOrReleaseBranch(repo: Repository) -> Bool {
        repo.primaryBranch == self ||
        self.isSuffixedWithStableOrPartialStableSemVer
    }

    private var isSuffixedWithStableOrPartialStableSemVer: Bool {
        let punctuationIndices = self.enumerated()
            .filter(\.element.isPunctuation)
            .map(\.offset)

        /// If there is a valid SemVer suffixed in the string, return `true`.
        for idx in punctuationIndices.reversed() {
            let nextIndex = self.index(
                self.startIndex,
                offsetBy: idx + 1
            )
            let afterThePunctuation = self[nextIndex...]
            if afterThePunctuation.isStableOrPartialStableSemVer {
                return true
            }
        }

        return false
    }

    private var isStableOrPartialStableSemVer: Bool {
        /// The pattern is from the link below, with modifications:
        /// 1- Allow for some `.x`s.
        /// 2- Don't care about pre-release and build identifies.
        /// https://github.com/gwynne/swift-semver/blob/main/Sources/SwiftSemver/SemanticVersion.swift
        let pattern = #/^(\d+)(\.(([1-9]+)))?(\.(([1-9]+|x)))$/#
        return self.wholeMatch(of: pattern) != nil
    }
}
