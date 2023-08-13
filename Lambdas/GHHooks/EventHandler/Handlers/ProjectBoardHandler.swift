import DiscordBM
import GitHubAPI

struct ProjectBoardHandler {
    let context: HandlerContext
    let action: Issue.Action
    let issue: Issue
    var event: GHEvent {
        context.event
    }
    var repo: Repository {
        get throws {
            try event.repository.requireValue()
        }
    }

    init(context: HandlerContext, action: Issue.Action, issue: Issue) throws {
        self.context = context
        self.action = action
        self.issue = issue
    }

    func handle() async throws {
        switch action {
        case .labeled:
            try await onLabeled()
        case .unlabeled:
            try await onUnlabeled()
        case .assigned:
            try await onAssigned()
        case .unassigned:
            try await onUnassigned()
        case .closed:
            try await onClosed()
        case .reopened:
            try await onReopened()
        default: break
        }
    }

    func onLabeled() async throws {

    }

    func onUnlabeled() async throws {

    }

    func onAssigned() async throws {

    }

    func onUnassigned() async throws {

    }

    func onClosed() async throws {

    }

    func onReopened() async throws {

    }
}
