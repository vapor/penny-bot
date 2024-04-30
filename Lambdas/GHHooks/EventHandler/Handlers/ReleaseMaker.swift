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
        static let releaseNoticePrefix = "**These changes are now available in"
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
              pr.base.ref.isPrimaryOrReleaseBranch(repo: repo),
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

        try await updatePRBodyWithReleaseNotice(release: release)
    }

    func getLastRelease() async throws -> Release {
        let latest = try await self.getLatestRelease()

        let releases = try await context.githubClient.repos_list_releases(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            )
        ).ok.body.json

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
        let response = try await context.githubClient.repos_get_latest_release(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            )
        )

        if case let .ok(ok) = response,
           case let .json(json) = ok.body {
            return json
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
        return try await context.githubClient.repos_create_release(
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
        ).created.body.json
    }

    func updatePRBodyWithReleaseNotice(release: Release) async throws {
        let current = try await context.githubClient.pulls_get(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                pull_number: number
            )
        ).ok.body.json
        if (current.body ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .hasPrefix(Configuration.releaseNoticePrefix) {
            logger.debug("Pull request doesn't need to be updated with release notice", metadata: [
                "current": "\(current)"
            ])
            return
        }
        let updated = try await context.githubClient.pulls_update(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                pull_number: number
            ),
            body: .json(.init(
                body: """
                \(Configuration.releaseNoticePrefix) [\(release.tag_name)](\(release.html_url))**


                \(current.body ?? "")
                """
            ))
        ).ok.body.json
        logger.debug("Updated a pull request with a release notice", metadata: [
            "before": "\(current)",
            "after": "\(updated)"
        ])
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
        let codeOwners = try await context.requester.getCodeOwners(
            repoFullName: repo.full_name,
            branch: pr.base.ref
        )
        let contributors = try await getExistingContributorIDs()
        let isNewContributor = isNewContributor(
            codeOwners: codeOwners,
            existingContributors: contributors
        )
        let reviewers = try await getReviewersToCredit(codeOwners: codeOwners).map(\.uiName)

        let bodyNoReleaseNotice = pr.body.map { $0.trimmingReleaseNoticeFromBody() } ?? ""
        let body = bodyNoReleaseNotice.formatMarkdown(
            maxVisualLength: 1_024,
            hardLimit: 2_048,
            trailingTextMinLength: 128
        ).quotedMarkdown()

        return try await context.renderClient.newReleaseDescription(
            context: .init(
                pr: .init(
                    title: pr.title,
                    body: body,
                    author: pr.user.uiName,
                    number: number
                ),
                isNewContributor: isNewContributor,
                reviewers: reviewers,
                merged_by: mergedBy.uiName,
                repo: .init(fullName: repo.full_name),
                release: .init(
                    oldTag: previousVersion,
                    newTag: newVersion
                )
            )
        )
    }

    func getReviewersToCredit(codeOwners: CodeOwners) async throws -> [User] {
        let usernames = codeOwners.union([pr.user.login])
        let reviewComments = try await getReviewComments()
        let reviewers = reviewComments.map(\.user).filter { user in
            !(usernames.contains(user: user) || user.isBot)
        }
        let groupedReviewers = Dictionary(grouping: reviewers, by: \.id)
        let sorted = groupedReviewers.values.sorted(by: { $0.count > $1.count }).map(\.[0])
        return sorted
    }

    func isNewContributor(codeOwners: CodeOwners, existingContributors: Set<Int>) -> Bool {
        pr.author_association != .OWNER &&
        !pr.user.isBot &&
        !codeOwners.contains(user: pr.user) &&
        !existingContributors.contains(pr.user.id)
    }

    func getReviewComments() async throws -> [PullRequestReviewComment] {
        let response = try await context.githubClient.pulls_list_review_comments(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                pull_number: number
            )
        )

        if case let .ok(ok) = response,
           case let .json(json) = ok.body {
            return json
        } else {
            logger.warning("Could not find review comments", metadata: [
                "response": "\(response)"
            ])
            return []
        }
    }

    func getExistingContributorIDs() async throws -> Set<Int> {
        var page = 1
        var contributorIds: [Int] = []
        /// Hack: Vapor has around this amount of contributors and we know it, so better
        /// to reserve enough capacity for it up-front.
        contributorIds.reserveCapacity(250)
        while true {
            let (ids, hasNext) = try await self.getExistingContributorIDs(page: page)
            if ids.isEmpty {
                break
            }
            contributorIds.append(contentsOf: consume ids)
            guard hasNext else { break }
            page += 1
        }
        return Set(contributorIds)
    }

    func getExistingContributorIDs(page: Int) async throws -> (ids: [Int], hasNext: Bool) {
        logger.debug("Will fetch current contributors", metadata: [
            "page": .stringConvertible(page)
        ])

        let response = try await context.githubClient.repos_list_contributors(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            ),
            query: .init(
                per_page: 100,
                page: page
            )
        )

        if case let .ok(ok) = response,
           case let .json(json) = ok.body {
            /// Example of a `link` header: `<https://api.github.com/repositories/49910095/contributors?page=6>; rel="prev", <https://api.github.com/repositories/49910095/contributors?page=8>; rel="next", <https://api.github.com/repositories/49910095/contributors?page=8>; rel="last", <https://api.github.com/repositories/49910095/contributors?page=1>; rel="first"`
            /// If the header contains `rel="next"` then we'll have a next page to fetch.
            let hasNext = switch ok.headers.Link {
            case let .case1(string):
                string.contains(#"rel="next""#)
            case let .case2(strings):
                strings.contains { $0.contains(#"rel="next""#) }
            case .none:
                false
            }
            let ids = json.compactMap(\.id)
            logger.debug("Fetched some contributors", metadata: [
                "page": .stringConvertible(page),
                "count": .stringConvertible(ids.count)
            ])
            return (ids, hasNext)
        } else {
            logger.error("Error when fetching contributors but will continue", metadata: [
                "page": .stringConvertible(page),
                "response": "\(response)"
            ])
            return ([], false)
        }
    }
}

extension String {
    func trimmingReleaseNoticeFromBody() -> String {
        let trimmedBody = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBody.hasPrefix(ReleaseMaker.Configuration.releaseNoticePrefix) {
            return trimmedBody.split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .dropFirst()
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return trimmedBody
        }
    }
}
