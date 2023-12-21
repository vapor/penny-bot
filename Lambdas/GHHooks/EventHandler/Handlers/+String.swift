import GitHubAPI
import Logging

extension String? {
    /// Usage example: `context.event.ref.extractHeadBranchFromRef()`
    func extractHeadBranchFromRef() -> Substring? {
        guard let ref = self, ref.hasPrefix("refs/heads/") else {
            return nil
        }
        return ref.dropFirst(11)
    }
}

extension StringProtocol where Self: Sendable, SubSequence == Substring  {
    func isPrimaryOrReleaseBranch(repo: Repository) -> Bool {
        let result = repo.primaryBranch == self ||
        self.isSuffixedWithStableOrPartialStableSemVer
        Logger(label: "StringProtocol.isPrimaryOrReleaseBranch").debug(
            "Checking branch status for 'isPrimaryOrReleaseBranch'", metadata: [
                "branch": .stringConvertible(self),
                "isPrimaryOrReleaseBranch": .stringConvertible(result),
            ]
        )
        return result
    }

    private var isSuffixedWithStableOrPartialStableSemVer: Bool {
        self.enumerated()
            .filter(\.element.isPunctuation)
            .map(\.offset)
            .contains { idx in
                let nextIndex = self.index(
                    self.startIndex,
                    offsetBy: idx + 1
                )
                let afterThePunctuation = self[nextIndex...]
                return afterThePunctuation.isStableOrPartialStableSemVer
            }
    }

    private var isStableOrPartialStableSemVer: Bool {
        /// The pattern is from the link below, with modifications:
        /// 1- Allow for some `.x`s.
        /// 2- Reject pre-release and build identifies.
        /// https://github.com/gwynne/swift-semver/blob/main/Sources/SwiftSemver/SemanticVersion.swift
        let pattern = #/^(\d+)(\.(([1-9]+)))?(\.(([1-9]+|x)))$/#
        return self.wholeMatch(of: pattern) != nil
    }
}
