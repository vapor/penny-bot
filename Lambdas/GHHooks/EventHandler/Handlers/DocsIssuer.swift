import GitHubAPI
import DiscordBM

/// Sends a "Need translation" message for pull requests that don't have the ""
struct DocsIssuer {

    enum Configuration {
        static let docsRepoID = 64560805
    }

    let context: HandlerContext
    let pr: PullRequest
    let number: Int
    let repo: Repository

    init(context: HandlerContext, pr: PullRequest) throws {
        self.context = context
        self.pr = pr
        self.number = try context.event.number.requireValue()
        self.repo = try context.event.repository.requireValue()
    }

    func handle() async throws {
        guard repo.id == Configuration.docsRepoID,
              isNotExemptFromNewIssues()
        else { return }
        try await fileIssue()
    }

    func isNotExemptFromNewIssues() -> Bool {
        Set(pr.knownLabels).intersection([.translationUpdate, .noTranslationNeeded]).isEmpty
    }

    func getPRsRelatedToCommit(commitSha: String) async throws -> [SimplePullRequest] {
        let response = try await context.githubClient.
        repos_list_pull_requests_associated_with_commit(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                commit_sha: commitSha
            )
        ))

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body else {
            throw Errors.httpRequestFailed(response: response)
        }

        return json
    }

    func getPRFiles(number: Int) async throws -> [DiffEntry] {
        let response = try await context.githubClient.pulls_list_files(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                pull_number: number
            )
        ))

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body else {
            throw Errors.httpRequestFailed(response: response)
        }

        return json
    }

    func fileIssue() async throws {
        let response = try await context.githubClient.issues_create(.init(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name
            ),
            body: .json(.init(
                title: .case1(self.makeIssueTitle()),
                body: self.makeIssueDescription()
            ))
        ))

        guard case .created = response else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    func makeIssueTitle() -> String {
        "Translation needed for #\(number)"
    }

    func makeIssueDescription() -> String {
        return """
        ---
        title: Translation needed for #\(number)
        ---

        The docs have been updated in PR #\(number). The translations should be updated if required.

        Languages:
        - [ ] English
        - [ ] Chinese
        - [ ] German
        - [ ] Dutch
        - [ ] Italian
        - [ ] Spanish
        - [ ] Polish
        - [ ] Korean

        Assigned to @vapor/translators - please submit a PR with the relevant updates and check the box once merged. Please ensure you tag your PR with the `translation-update` so it doesn't create a new issue!
        """
    }
}
