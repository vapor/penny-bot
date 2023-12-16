import DiscordBM
import GitHubAPI
import Logging

/// Files a "Need translation" issue for each PR in a push-commit that needs that.
struct DocsIssuer {
    enum Configuration {
        static let docsRepoID = 64_560_805
    }

    let context: HandlerContext
    let commitSHA: String
    let repo: Repository
    var event: GHEvent {
        self.context.event
    }

    var logger: Logger {
        self.context.logger
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.commitSHA = try context.event.after.requireValue()
        self.repo = try context.event.repository.requireValue()
    }

    func handle() async throws {
        guard self.repo.id == Configuration.docsRepoID else {
            return
        }
        guard let branch = self.event.ref.extractHeadBranchFromRef(),
              branch.isPrimaryOrReleaseBranch(repo: repo)
        else { return }

        for pr in try await self.getPRsRelatedToCommit() {
            guard self.needsNewIssue(pr: pr) else {
                self.logger.debug(
                    "Will not file issue for docs push PR because it's exempt from new issues",
                    metadata: ["number": .stringConvertible(pr.number)]
                )
                continue
            }
            let files = try await getPRFiles(number: pr.number)
            /// PR must contain file changes for files that are in the `docs` directory.
            /// Otherwise there is nothing to be translated and there is no need for a new issue.
            guard files.contains(where: { file in
                file.filename.hasPrefix("docs/") &&
                    [.added, .modified].contains(file.status)
            }) else {
                self.logger.debug(
                    "Will not file issue for docs push PR because no docs files are added or modified",
                    metadata: ["number": .stringConvertible(pr.number)]
                )
                continue
            }
            try await self.fileIssue(number: pr.number)
        }
    }

    /// Should not contain any labels that indicate no need for a new issue.
    func needsNewIssue(pr: SimplePullRequest) -> Bool {
        Set(pr.knownLabels).intersection([.translationUpdate, .noTranslationNeeded]).isEmpty
    }

    func getPRsRelatedToCommit() async throws -> [SimplePullRequest] {
        try await context.githubClient.repos_list_pull_requests_associated_with_commit(
            path: .init(
                owner: self.repo.owner.login,
                repo: self.repo.name,
                commit_sha: self.commitSHA
            )
        ).ok.body.json
    }

    func getPRFiles(number: Int) async throws -> [DiffEntry] {
        try await context.githubClient.pulls_list_files(
            path: .init(
                owner: self.repo.owner.login,
                repo: self.repo.name,
                pull_number: number
            )
        ).ok.body.json
    }

    func fileIssue(number: Int) async throws {
        let description = try await context.renderClient.translationNeededDescription(number: number)
        _ = try await context.githubClient.issues_create(
            path: .init(
                owner: self.repo.owner.login,
                repo: self.repo.name
            ),
            body: .json(.init(
                title: .case1("Translation needed for #\(number)"),
                body: description
            ))
        ).created
    }
}
