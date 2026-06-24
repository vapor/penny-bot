import typealias GitHubAPI.Repository

struct ReleaseBranch {
    let name: String
    let majorVersion: Int?

    init?<S: StringProtocol & Sendable>(
        branch: S,
        repo: Repository
    ) where S.SubSequence == Substring {
        let branch = Self.extractBranch(from: branch)
        if repo.primaryBranch == branch {
            self.majorVersion = nil
        } else if branch.hasAcceptablePrefix(repo: repo),
            branch.isSuffixedWithStableOrPartialStableSemVer
        {
            self.majorVersion = Self.majorVersion(of: branch, repo: repo)
        } else {
            return nil
        }
        self.name = String(branch)
    }

    private static func extractBranch(from branch: some StringProtocol) -> String {
        guard branch.hasPrefix("refs/heads/") else {
            return String(branch)
        }
        return String(branch.dropFirst(11))
    }

    private static func majorVersion(of branch: some StringProtocol, repo: Repository) -> Int? {
        let lowercased = branch.lowercased()
        guard let prefix = [repo.name.lowercased(), "release"].first(where: { lowercased.hasPrefix($0) })
        else { return nil }
        var rest = branch.dropFirst(prefix.count)
        guard rest.first?.isPunctuation == true else { return nil }
        rest = rest.dropFirst()
        return Int(rest.prefix(while: \.isNumber))
    }
}

extension StringProtocol where Self: Sendable, SubSequence == Substring {
    fileprivate var isSuffixedWithStableOrPartialStableSemVer: Bool {
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

    fileprivate var isStableOrPartialStableSemVer: Bool {
        /// The pattern is from the link below, with modifications:
        /// 1- Allow for some `.x`s.
        /// 2- Reject pre-release and build identifies.
        /// https://github.com/gwynne/swift-semver/blob/main/Sources/SwiftSemver/SemanticVersion.swift
        let pattern = #/^(\d+)(\.(([1-9]+|x)))?(\.(([1-9]+|x)))?$/#
        return self.wholeMatch(of: pattern) != nil
    }

    fileprivate func hasAcceptablePrefix(repo: Repository) -> Bool {
        let lowercased = self.lowercased()
        return [repo.name.lowercased(), "release"].contains {
            lowercased.hasPrefix($0)
        }
    }
}
