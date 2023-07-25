import DiscordBM
import AsyncHTTPClient
import NIOCore
import NIOFoundationCompat
import GitHubAPI
import SwiftSemver
import Markdown
import Logging
import Foundation

struct ReleaseMaker {

    enum Configuration {
        static let repositoryIDDenyList: Set<Int> = [/*postgres-nio:*/ 150622661]
        /// Needs the Penny installation to be installed on the org,
        /// which is not possible without making Penny app public.
        static let organizationIDAllowList: Set<Int> = [/*vapor:*/ 17364220]
    }

    enum PRErrors: Error, CustomStringConvertible {
        case tagDoesNotFollowSemVer(release: Release, tag: String)
        case cantBumpSemVer(version: SemanticVersion, bump: SemVerBump)
        case cantFindAnyRelease(latest: Release?, releases: [Release])

        var description: String {
            switch self {
            case let .tagDoesNotFollowSemVer(release, tag):
                return "tagDoesNotFollowSemVer(release: \(release), tag: \(tag))"
            case let .cantBumpSemVer(version, bump):
                return "cantBumpSemVer(version: \(version), bump: \(bump))"
            case let .cantFindAnyRelease(latest, releases):
                return "cantFindAnyRelease(latest: \(String(describing: latest)), releases: \(releases))"
            }
        }
    }

    let context: HandlerContext
    let pr: PullRequest
    let number: Int
    let repo: Repository
    var event: GHEvent {
        context.event
    }
    var logger: Logger {
        context.logger
    }

    init(context: HandlerContext, pr: PullRequest, number: Int) throws {
        self.context = context
        self.pr = pr
        self.number = number
        self.repo = try context.event.repository.requireValue()
    }

    func handle() async throws {
        guard !Configuration.repositoryIDDenyList.contains(repo.id),
              Configuration.organizationIDAllowList.contains(repo.owner.id),
              let mergedBy = pr.merged_by,
              pr.base.ref == "main",
              let bump = pr.knownLabels.first?.toBump()
        else { return }

        let previousRelease = try await getLastRelease()

        let previousTag = previousRelease.tag_name
        guard let (tagPrefix, previousVersion) = SemanticVersion.fromGitHubTag(previousTag) else {
            throw PRErrors.tagDoesNotFollowSemVer(release: previousRelease, tag: previousTag)
        }

        guard let version = previousVersion.next(bump) else {
            throw PRErrors.cantBumpSemVer(version: previousVersion, bump: bump)
        }
        let versionDescription = tagPrefix + version.description

        let release = try await makeNewRelease(
            previousVersion: previousTag,
            newVersion: versionDescription,
            mergedBy: mergedBy,
            isPrerelease: !version.prereleaseIdentifiers.isEmpty
        )

        try await sendComment(release: release)
        try await sendToDiscord(release: release)
    }

    func getLastRelease() async throws -> Release {
        let latest = try await self.getLatestRelease()

        let response = try await context.githubClient.repos_list_releases(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            )
        ))

        guard case let .ok(ok) = response,
              case let .json(releases) = ok.body
        else {
            throw Errors.httpRequestFailed(response: response)
        }

        let filteredReleases: [Release] = releases.compactMap {
            release -> (Release, SemanticVersion)? in
            if let (_, version) = SemanticVersion.fromGitHubTag(release.tag_name) {
                return (release, version)
            }
            return nil
        }.filter { release, version -> Bool in
            if let majorVersion = Int(pr.base.ref) {
                /// If the branch name is an integer, only include releases
                /// for that major version.
                return version.major == majorVersion
            }
            return true
        }.sorted {
            $0.1 > $1.1
        }.sorted { (lhs, rhs) in
            if let latest {
                return latest.id == lhs.0.id
            }
            return true
        }.map(\.0)

        guard let release = filteredReleases.first else {
            throw PRErrors.cantFindAnyRelease(latest: latest, releases: releases)
        }

        return release
    }

    private func getLatestRelease() async throws -> Release? {
        let response = try await context.githubClient.repos_get_latest_release(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            )
        ))

        switch response {
        case let .ok(ok):
            switch ok.body {
            case let .json(json):
                return json
            }
        default: break
        }

        logger.warning("Could not find a 'latest' release", metadata: [
            "owner": .string(repo.owner.login),
            "name": .string(repo.name),
            "response": "\(response)",
        ])

        return nil
    }

    func makeNewRelease(
        previousVersion: String,
        newVersion: String,
        mergedBy: NullableUser,
        isPrerelease: Bool
    ) async throws -> Release {
        let body = try await makeReleaseBody(
            mergedBy: mergedBy,
            previousVersion: previousVersion,
            newVersion: newVersion
        )
        let response = try await context.githubClient.repos_create_release(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            ),
            body: .json(.init(
                tag_name: newVersion,
                target_commitish: pr.base.ref,
                name: "\(newVersion) - \(pr.title)",
                body: body,
                draft: false,
                prerelease: isPrerelease,
                make_latest: isPrerelease ? ._false : ._true
            ))
        ))

        switch response {
        case let .created(created):
            switch created.body {
            case let .json(release):
                return release
            }
        default: break
        }

        throw Errors.httpRequestFailed(response: response)
    }

    func sendComment(release: Release) async throws {
        /// `"Issues" create comment`, but works for PRs too. Didn't find an endpoint for PRs.
        let response = try await context.githubClient.issues_create_comment(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                issue_number: number
            ),
            body: .json(.init(
                body: """
                These changes are now available in [\(release.tag_name)](\(release.html_url))
                """
            ))
        ))

        switch response {
        case .created: return
        default:
            throw Errors.httpRequestFailed(response: response)
        }
    }

    /**
     - A user who appears in a given repo's code owners file should NOT be credited as either an author or reviewer for a release in that repo (but can still be credited for releasing it).
     - The user who authored the PR should be credited unless they are a code owner. Such a credit should be prominent and - as the GitHub changelog generator does - include a notation if it's that user's first merged PR.
     - Any users who reviewed the PR (even if they requested changes or did a comments-only review without approving) should also be credited unless they are code owners. Such a credit should be less prominent than the author credit, something like a "thanks to ... for helping to review this release"
     - The release author (user who merged the PR) should always be credited in a release, even if they're a code owner. This credit should be the least prominent, maybe even just a footnote (since it will pretty much always be a owner/maintainer).
     */
    func makeReleaseBody(
        mergedBy: NullableUser,
        previousVersion: String,
        newVersion: String
    ) async throws -> String {
        let codeOwners = try await getCodeOwners()
        let contributors = try await getExistingContributorIDs()
        let isNewContributor = isNewContributor(
            codeOwners: codeOwners,
            existingContributors: contributors
        )
        let reviewers = try await getReviewersToCredit(codeOwners: codeOwners)
        let isCodeOwner = codeOwners.usernamesContain(user: pr.user)

        return """
        \(makePRMarkdown(isCodeOwner: isCodeOwner))
        \(makeContributorMarkdown(isNewContributor: isNewContributor))
        \(makeReviewersMarkdown(reviewers: reviewers))
        \(makeMergerMarkdown(mergedBy: mergedBy))
        \(makeChangeLogMarkdown(previousVersion: previousVersion, newVersion: newVersion))
        """
    }

    func makeMergerMarkdown(mergedBy: NullableUser) -> String {
        """
        ###### _This patch was released by @\(mergedBy.name ?? mergedBy.login)._

        """
    }

    func makePRMarkdown(isCodeOwner: Bool) -> String {
        let body = pr.body.map {
            "> " + $0.formatMarkdown(
                maxLength: 512,
                trailingParagraphMinLength: 128
            ).replacingOccurrences(
                of: "\n",
                with: "\n> "
            )
        } ?? ""
        return """
        ## What's Changed
        \(pr.title) by @\(pr.user.name ?? pr.user.login) in #\(number)

        \(body)

        """
    }

    func makeContributorMarkdown(isNewContributor: Bool) -> String {
        guard isNewContributor else { return "" }
        return """
        ## New Contributor
        - @\(pr.user.name ?? pr.user.login) made their first contribution 🎉
        
        """
    }

    func makeReviewersMarkdown(reviewers: [User]) -> String {
        if reviewers.isEmpty { return "" }
        let reviewersText = reviewers.map { user in
            "- @\(user.name ?? user.login)"
        }.joined(separator: "\n")
        return """
        ## Reviewers
        Thanks to the reviewers for their help:
        \(reviewersText)

        """
    }

    func makeChangeLogMarkdown(previousVersion: String, newVersion: String) -> String {
        let fullName = repo.full_name.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? repo.full_name
        let url = "https://github.com/\(fullName)/compare/\(previousVersion)...\(newVersion)"
        return "**Full Changelog**: \(url)"
    }

    func getReviewersToCredit(codeOwners: Set<String>) async throws -> [User] {
        let usernames = codeOwners.union([pr.user.login])
        let reviewComments = try await getReviewComments()
        let reviewers = reviewComments.map(\.user).filter { user in
            !(usernames.usernamesContain(user: user) || user.isBot)
        }
        let groupedReviewers = Dictionary(grouping: reviewers, by: \.id)
        let sorted = groupedReviewers.values.sorted(by: { $0.count > $1.count }).map(\.[0])
        return sorted
    }

    func isNewContributor(codeOwners: Set<String>, existingContributors: Set<Int>) -> Bool {
        if pr.author_association == .OWNER ||
            pr.user.isBot ||
            codeOwners.usernamesContain(user: pr.user) {
            return false
        }
        return !existingContributors.contains(pr.user.id)
    }

    func getReviewComments() async throws -> [PullRequestReviewComment] {
        let response = try await context.githubClient.pulls_list_review_comments(
            .init(path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                pull_number: number
            ))
        )

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body
        else {
            logger.warning("Could not find review comments", metadata: [
                "response": "\(response)"
            ])
            return []
        }

        return json
    }

    func getExistingContributorIDs() async throws -> Set<Int> {
        let response = try await context.githubClient.repos_list_contributors(
            .init(path: .init(
                owner: repo.owner.login,
                repo: repo.name
            ))
        )

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body
        else {
            logger.warning("Could not find current contributors", metadata: [
                "response": "\(response)"
            ])
            return []
        }

        return Set(json.compactMap(\.id))
    }

    /// Returns code owners if the repo contains the file or returns `nil`.
    /// In form of `["gwynne", "0xTim"]`.
    func getCodeOwners() async throws -> Set<String> {
        let fullName = repo.full_name.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? repo.full_name
        let url = "https://raw.githubusercontent.com/\(fullName)/main/.github/CODEOWNERS"
        let request = HTTPClientRequest(url: url)
        let response = try await context.httpClient.execute(request, timeout: .seconds(3))
        let body = try await response.body.collect(upTo: 1 << 16)
        guard response.status == .ok else {
            logger.warning("Can't find code owners of repo", metadata: [
                "responseBody": "\(body)",
                "response": "\(response)"
            ])
            return []
        }
        let text = String(buffer: body)
        let parsed = parseCodeOwners(text: text)
        logger.debug("Parsed code owners", metadata: [
            "text": .string(text),
            "parsed": .stringConvertible(parsed)
        ])
        return parsed
    }

    func parseCodeOwners(text: String) -> Set<String> {
        let codeOwners: [String] = text
        /// split into lines
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
        /// trim leading whitespace per line
            .map { $0.trimmingPrefix(while: \.isWhitespace) }
        /// remove whole-line comments
            .filter { !$0.starts(with: "#") }
        /// remove partial-line comments
            .compactMap {
                $0.split(
                    separator: "#",
                    maxSplits: 1,
                    omittingEmptySubsequences: true
                ).first
            }
        /// split lines on whitespace, dropping first character, and combine to single list
            .flatMap { line -> [Substring] in
                line.split(
                    omittingEmptySubsequences: true,
                    whereSeparator: \.isWhitespace
                ).dropFirst().map { (user: Substring) -> Substring in
                    /// Drop the first character of each code-owner which is an `@`.
                    if user.first == "@" {
                        return user.dropFirst()
                    } else {
                        return user
                    }
                }
            }.map(String.init)

        return Set(codeOwners)
    }

    func sendToDiscord(release: Release) async throws {
        let body = pr.body.map { body -> String in
            let formatted = body.formatMarkdown(
                maxLength: 256,
                trailingParagraphMinLength: 128
            )
            return formatted.isEmpty ? "" : ">>> \(formatted)"
        } ?? ""

        let description = """
        ### \(pr.title)

        \(body)
        """
        let fullName = repo.full_name.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? repo.full_name
        let image = "https://opengraph.githubassets.com/\(UUID().uuidString)/\(fullName)/releases/tag/\(release.tag_name)"
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.release.id,
            payload: .init(
                embeds: [.init(
                    title: "[\(repo.uiName)] Release \(release.tag_name)".unicodesPrefix(256),
                    description: description,
                    url: release.html_url,
                    color: .cyan,
                    image: .init(url: .exact(image))
                )]
            )
        ).guardSuccess()
    }
}

private extension Set<String> {
    /// Only supports names, and not emails.
    func usernamesContain(user: User) -> Bool {
        if let name = user.name {
            return !self.intersection([user.login, name]).isEmpty
        } else {
            return self.contains(user.login)
        }
    }
}
