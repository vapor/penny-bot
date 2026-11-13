import Shared

enum CommentCommandError: Error, CustomStringConvertible {
    case unknownCommand(verb: String?)
    case notAPullRequest(command: CommentCommand)
    case insufficientAccess(login: String, repo: String, permission: String)
    case noWorkflow(command: CommentCommand, repo: String)
    case dispatchRejected(command: CommentCommand, repo: String, statusCode: Int, message: String)

    static let documentationURL = "https://github.com/vapor/penny-bot#comment-commands"

    var description: String {
        switch self {
        case let .unknownCommand(verb):
            return "unknownCommand(verb: \(verb ?? "<null>"))"
        case let .notAPullRequest(command):
            return "notAPullRequest(command: \(command))"
        case let .insufficientAccess(login, repo, permission):
            return "insufficientAccess(login: \(login), repo: \(repo), permission: \(permission))"
        case let .noWorkflow(command, repo):
            return "noWorkflow(command: \(command), repo: \(repo))"
        case let .dispatchRejected(command, repo, statusCode, message):
            return "dispatchRejected(command: \(command), repo: \(repo), "
                + "statusCode: \(statusCode), message: \(message))"
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
        case let .noWorkflow(command, repo):
            switch command {
            case .benchmark:
                return """
                    **`\(repo)` has no benchmark CI.**

                    See [`vapor/jwt-kit`'s](https://github.com/vapor/jwt-kit/blob/main/.github/workflows/\(command.workflowFileName)) as an example.
                    """
            case .deploy:
                return """
                    **`\(repo)` has no preview workflow.**

                    Add `\(command.workflowFileName)` on the default branch with a `workflow_dispatch` \
                    trigger accepting \(command.workflowInputsDescription).
                    """
            }
        case let .dispatchRejected(command, _, statusCode, message):
            return """
                **GitHub refused to start `\(command.workflowFileName)` (HTTP status code: \(statusCode)).**

                \(message.quotedMarkdown())

                Check that `\(command.workflowFileName)` on the default branch has a \
                `workflow_dispatch` trigger with \(command.workflowInputsDescription).
                """
        }
    }
}
