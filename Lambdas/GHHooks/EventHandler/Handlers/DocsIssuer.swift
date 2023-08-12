import DiscordBM
import GitHubAPI
import Logging

/// Sends a "Need translation" message for each PR in a push-commit that needs that.
struct DocsIssuer {

    enum Configuration {
        static let docsRepoID = 64_560_805
    }

    let context: HandlerContext
    let commitSHA: String
    let repo: Repository
    var event: GHEvent {
        context.event
    }
    var logger: Logger {
        context.logger
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.commitSHA = try context.event.after.requireValue()
        self.repo = try context.event.repository.requireValue()
    }

    func handle() async throws {
        guard repo.id == Configuration.docsRepoID else {
            return
        }
        guard event.ref == "refs/heads/\(repo.primaryBranch)" else {
            return
        }
        for pr in try await getPRsRelatedToCommit() {
            guard needsNewIssue(pr: pr) else {
                logger.debug(
                    "Will not file issue for docs push PR because it's exempt from new issues",
                    metadata: ["number": .stringConvertible(pr.number)]
                )
                continue
            }
            let files = try await getPRFiles(number: pr.number)
            /// PR must contain file changes for files that are in the `docs` directory.
            /// Otherwise there is nothing to be translated and there is no need for a new issue.
            guard
                files.contains(where: { file in
                    file.filename.hasPrefix("docs/") && [.added, .modified].contains(file.status)
                })
            else {
                logger.debug(
                    "Will not file issue for docs push PR because no docs files are added or modified",
                    metadata: ["number": .stringConvertible(pr.number)]
                )
                continue
            }
            try await fileIssue(number: pr.number)
        }
    }

    /// Should not contain any labels that indicate no need for a new issue.
    func needsNewIssue(pr: SimplePullRequest) -> Bool {
        Set(pr.knownLabels).intersection([.translationUpdate, .noTranslationNeeded]).isEmpty
    }

    func getPRsRelatedToCommit() async throws -> [SimplePullRequest] {
        let response = try await context.githubClient
            .repos_list_pull_requests_associated_with_commit(
                .init(
                    path: .init(
                        owner: repo.owner.login,
                        repo: repo.name,
                        commit_sha: commitSHA
                    )
                )
            )

        guard case let .ok(ok) = response,
            case let .json(json) = ok.body
        else {
            throw Errors.httpRequestFailed(response: response)
        }

        return json
    }

    func getPRFiles(number: Int) async throws -> [DiffEntry] {
        let response = try await context.githubClient.pulls_list_files(
            .init(
                path: .init(
                    owner: repo.owner.login,
                    repo: repo.name,
                    pull_number: number
                )
            )
        )

        guard case let .ok(ok) = response,
            case let .json(json) = ok.body
        else {
            throw Errors.httpRequestFailed(response: response)
        }

        return json
    }

    func fileIssue(number: Int) async throws {
        let description = try await context.renderClient.translationNeededDescription(
            number: number
        )
        let response = try await context.githubClient.issues_create(
            .init(
                path: .init(
                    owner: repo.owner.login,
                    repo: repo.name
                ),
                body: .json(
                    .init(
                        title: .case1("Translation needed for #\(number)"),
                        body: description
                    )
                )
            )
        )

        guard case .created = response else {
            throw Errors.httpRequestFailed(response: response)
        }
    }
}
