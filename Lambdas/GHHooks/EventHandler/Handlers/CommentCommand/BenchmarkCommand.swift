import DiscordBM
import GitHubAPI
import OpenAPIRuntime
import Shared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct BenchmarkCommand {
    enum Configuration {
        static let workflowFileName = "benchmark.yml"
        static let maxErrorBodyBytes = 1 << 16
        static let maxErrorMessageLength = 500
    }

    let context: HandlerContext
    let number: Int

    /// Returns the sha the benchmark workflow was dispatched against.
    func handle() async throws -> String {
        let repo = try self.context.event.repository.requireValue()
        let sha = try await self.findHeadSHA(repo: repo)
        try await self.dispatchWorkflow(repo: repo, sha: sha)
        return sha
    }

    /// The `issue_comment` payload's `issue.pull_request` only carries URLs, so the head sha
    /// has to be fetched. Fork PRs work too, `head.sha` is returned either way.
    func findHeadSHA(repo: Repository) async throws -> String {
        try await self.context.githubClient.pullsGet(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                pullNumber: self.number
            )
        ).ok.body.json.head.sha
    }

    func dispatchWorkflow(repo: Repository, sha: String) async throws {
        let response = try await self.context.githubClient.actionsCreateWorkflowDispatch(
            path: .init(
                owner: repo.owner.login,
                repo: repo.name,
                workflowId: .case2(Configuration.workflowFileName)
            ),
            body: .json(
                .init(
                    /// Not `Repository.primaryBranch`, which reads the legacy `master_branch`
                    /// field that `issue_comment` payloads don't carry.
                    ref: repo.defaultBranch,
                    inputs: .init(additionalProperties: try .init(unvalidatedValue: ["sha": sha]))
                )
            )
        )

        switch response {
        case .noContent, .ok:
            break
        case let .undocumented(statusCode, payload):
            switch statusCode {
            case 404:
                throw CommentCommandError.noBenchmarkWorkflow(repo: repo.fullName)
            default:
                let message = try await Self.retrieveGHErrorMessage(from: payload)
                throw CommentCommandError.dispatchRejected(
                    repo: repo.fullName,
                    statusCode: statusCode,
                    message: message
                )
            }
        }
    }

    static func retrieveGHErrorMessage(from payload: UndocumentedPayload) async throws -> String {
        guard let body = payload.body else {
            return "<no GitHub error message>"
        }
        let collected = try await String(collecting: body, upTo: Configuration.maxErrorBodyBytes)
        guard let json = try? JSONDecoder().decode(ErrorResponse.self, from: Data(collected.utf8)) else {
            return collected.unicodesPrefix(Configuration.maxErrorMessageLength)
        }
        return json.message.unicodesPrefix(Configuration.maxErrorMessageLength)
    }

    private struct ErrorResponse: Codable {
        let message: String
    }
}
