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
        let labels = issue.knownLabels.compactMap(ProjectBoardLabel.init(label:))
        for label in Set(labels) {

        }
        /**
        a. Set boards to ["Help Wanted Issues"] or ["Beginner Issues"] respectively.
        b. For each board in boards, remove issue from board if present.
        */
    }

    func onUnlabeled() async throws {
        let labels = issue.knownLabels.compactMap(ProjectBoardLabel.init(label:))
        for label in Set(labels) {

        }
        /**
         Set boards to ["Help Wanted Issues"] or ["Beginner Issues"] respectively.
        */
    }

    func onAssigned() async throws {
        /// If !event.issue.assignees.compacted().isEmpty, set column to "In Progress". Go to Step 7.
        /// Repeat for each board in boards:
        /// a. If issue present in board, move issue to column. Otherwise add issue to column in board.
    }

    func onUnassigned() async throws {
        /// If event.issue.assignees.compacted().isEmpty, set column to "To do". Go to Step 7.
        /// Repeat for each board in boards:
        /// a. If issue present in board, move issue to column. Otherwise add issue to column in board.
    }

    func onClosed() async throws {
        /**
        If event.issue.state == "closed", set column to "Done"
        Repeat for each board in boards:
        a. If issue present in board, move issue to column. Otherwise add issue to column in board.
        */
    }

    func onReopened() async throws {

    }
}

private enum ProjectBoardLabel: String {
    case helpWanted = "help wanted"
    case goodFirstIssue = "good first issue"

    var board: String {
        switch self {
        case .helpWanted:
            return "Help Wanted Issues"
        case .goodFirstIssue:
            return "Beginner Issues"
        }
    }

    init?(label: Issue.KnownLabel) {
        switch label {
        case .helpWanted:
            self = .helpWanted
        case .goodFirstIssue:
            self = .goodFirstIssue
        default:
            return nil
        }
    }
}
