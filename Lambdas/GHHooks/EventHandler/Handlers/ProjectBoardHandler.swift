import DiscordBM
import GitHubAPI

struct ProjectBoardHandler {
    let context: HandlerContext
    let kind: Issue.Action
    let issue: Issue
    var event: GHEvent {
        context.event
    }
    var repo: Repository {
        get throws {
            try event.repository.requireValue()
        }
    }

    init(context: HandlerContext, kind: Issue.Action, issue: Issue) throws {
        self.context = context
        self.kind = kind
        self.issue = issue
    }

    func handle() async throws {
        switch kind {
        case .labeled: 
            try await onLabeled()
        case .unlabeled: break
            try await onUnlabeled()
        case .assigned: break
            try await onAssigned()
        case .unassigned: break
            try await onUnassigned()
        case .closed: break
            try await onClosed()
        case .reopened: break
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
