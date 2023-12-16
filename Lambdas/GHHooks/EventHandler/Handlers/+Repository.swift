import GitHubAPI

extension Repository {
    func isPrimaryOrReleaseBranch<StringProto>(_ branch: StringProto) -> Bool
    where StringProto: StringProtocol, StringProto.SubSequence == Substring {
        self.primaryBranch == branch ||
        branch.isSuffixedWithStableOrPartialStableSemVer
    }
}

private extension StringProtocol where SubSequence == Substring {
    var isSuffixedWithStableOrPartialStableSemVer: Bool {
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
}

private extension StringProtocol where SubSequence == Substring {
    var isStableOrPartialStableSemVer: Bool {
        /// The pattern is from the link below, with modifications:
        /// 1- Allow for some `.x`s.
        /// 2- Don't care about pre-release and build identifies.
        /// https://github.com/gwynne/swift-semver/blob/main/Sources/SwiftSemver/SemanticVersion.swift
        let pattern = #/^(\d+)(\.(([1-9]+)))?(\.(([1-9]+|x)))$/#
        return self.wholeMatch(of: pattern) != nil
    }
}
