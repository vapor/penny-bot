import Shared

enum CommentCommandError: Error, CustomStringConvertible {
    case unknownCommand(verb: String?)
    case notAPullRequest(command: CommentCommand)
    case insufficientAccess(login: String, repo: String, permission: String)
    case noBenchmarkWorkflow(repo: String)
    case dispatchRejected(repo: String, statusCode: Int, message: String)

    static let documentationURL = "https://github.com/vapor/penny-bot#comment-commands"

    var description: String {
        switch self {
        case let .unknownCommand(verb):
            return "unknownCommand(verb: \(verb ?? "<null>"))"
        case let .notAPullRequest(command):
            return "notAPullRequest(command: \(command))"
        case let .insufficientAccess(login, repo, permission):
            return "insufficientAccess(login: \(login), repo: \(repo), permission: \(permission))"
        case let .noBenchmarkWorkflow(repo):
            return "noBenchmarkWorkflow(repo: \(repo))"
        case let .dispatchRejected(repo, statusCode, message):
            return "dispatchRejected(repo: \(repo), statusCode: \(statusCode), message: \(message))"
        }
    }

    var commentBody: String {
        switch self {
        case let .unknownCommand(verb):
            let title =
                verb.map { "**`\($0.unicodesPrefix(50))` isn't a command.**" }
                ?? "**Write a command after the mention.**"
            let commands = CommentCommand.allCases.map { "- `@penny \($0.rawValue)`" }.joined(separator: "\n")
            return """
                \(title)

                Available commands:
                \(commands)

                [What each one does](\(Self.documentationURL))
                """
        case let .notAPullRequest(command):
            return """
                **`@penny \(command.rawValue)` only works on pull requests, not issues.**
                """
        case let .insufficientAccess(login, repo, permission):
            return """
                **@\(login), you need `write` access to `\(repo)` to run this. You have `\(permission)`.**

                This is inline with the access-level GitHub requires you to have to approve a workflow run. \
                Ask a maintainer to run the command for you.
                """
        case let .noBenchmarkWorkflow(repo):
            return """
                **`\(repo)` has no benchmark CI.**

                See [`vapor/jwt-kit`'s](https://github.com/vapor/jwt-kit/blob/main/.github/workflows/\(BenchmarkCommand.Configuration.workflowFileName)) as an example.
                """
        case let .dispatchRejected(_, statusCode, message):
            return """
                **GitHub refused to start the benchmark workflow (HTTP status code: \(statusCode)).**

                \(message.quotedMarkdown())

                Check that `\(BenchmarkCommand.Configuration.workflowFileName)` on the default branch has a \
                `workflow_dispatch` trigger with a required `sha` input.
                """
        }
    }
}
