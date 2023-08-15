import DiscordBM
import GitHubAPI

struct ProjectBoardHandler {
    let context: HandlerContext
    let action: Issue.Action
    let issue: Issue
    let repo: Repository
    var event: GHEvent {
        self.context.event
    }

    var note: String {
        self.issue.html_url
    }

    init(context: HandlerContext, action: Issue.Action, issue: Issue) throws {
        self.context = context
        self.action = action
        self.issue = issue
        self.repo = try self.context.event.repository.requireValue()
    }

    func handle() async throws {
        switch self.action {
        case .labeled:
            try await self.onLabeled()
        case .unlabeled:
            try await self.onUnlabeled()
        case .assigned:
            try await self.onAssigned()
        case .unassigned:
            try await self.onUnassigned()
        case .closed:
            try await self.onClosed()
        case .reopened:
            try await self.onReopened()
        default: break
        }
    }

    func onLabeled() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        for project in Set(relatedProjects) {
            let toDoColumnID = project.columnID(of: .toDo)

            func cards(column: Project.Column) async throws -> [ProjectCard] {
                try await self.getCards(columnID: project.columnID(of: column))
            }

            func move(cardID: Int) async throws {
                try await self.moveCard(toColumnID: toDoColumnID, cardID: cardID)
            }

            let inProgressCards = try await cards(column: .inProgress)

            if let card = inProgressCards.firstCard(note: note) {
                try await move(cardID: card.id)
                continue
            }

            let doneCards = try await cards(column: .done)

            if let card = doneCards.firstCard(note: note) {
                try await move(cardID: card.id)
                continue
            }

            let toDoCards = try await cards(column: .toDo)
            if !toDoCards.containsCard(note: self.note) {
                try await self.createCard(columnID: toDoColumnID, note: self.note)
            }
        }
    }

    func onUnlabeled() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        for project in Set(relatedProjects) {
            for column in Project.Column.allCases {
                let cards = try await self.getCards(columnID: project.columnID(of: column))
                if let card = cards.firstCard(note: note) {
                    try await self.deleteCard(cardID: card.id)
                }
            }
        }
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

    func onReopened() async throws {}

    func createCard(columnID: Int, note _: String) async throws {
        let response = try await self.context.githubClient.projects_create_card(.init(
            path: .init(column_id: columnID),
            /// Yes, send the raw url in body. GitHub will take care of properly showing it.
            /// If you send customized text instead, the card won't be recognized as a issue-card.
            body: .json(.case1(.init(note: self.note)))
        ))

        guard case .created = response else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    func moveCard(toColumnID columnID: Int, cardID: Int) async throws {
        let response = try await self.context.githubClient.projects_move_card(.init(
            path: .init(card_id: cardID),
            body: .json(.init(position: "top", column_id: columnID))
        ))

        guard case .created = response else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    func deleteCard(cardID: Int) async throws {
        let response = try await self.context.githubClient.projects_delete_card(.init(
            path: .init(card_id: cardID)
        ))

        guard case .noContent = response else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    func getCards(columnID: Int) async throws -> [ProjectCard] {
        let response = try await self.context.githubClient.projects_list_cards(.init(
            path: .init(column_id: columnID)
        ))

        guard case let .ok(ok) = response,
              case let .json(json) = ok.body
        else {
            throw Errors.httpRequestFailed(response: response)
        }

        return json
    }
}

private enum Project: String, CaseIterable {
    case helpWanted
    case beginner

    enum Column: CaseIterable {
        case toDo
        case inProgress
        case done
    }

    var id: Int {
        switch self {
        case .helpWanted:
            return 14_402_911
        case .beginner:
            return 14_183_112
        }
    }

    func columnID(of column: Column) -> Int {
        switch self {
        case .helpWanted:
            switch column {
            case .toDo:
                return 18_549_893
            case .inProgress:
                return 18_549_894
            case .done:
                return 18_549_895
            }
        case .beginner:
            switch column {
            case .toDo:
                return 17_909_684
            case .inProgress:
                return 17_909_685
            case .done:
                return 17_909_686
            }
        }
    }

    init?(label: Issue.KnownLabel) {
        switch label {
        case .helpWanted:
            self = .helpWanted
        case .goodFirstIssue:
            self = .beginner
        default:
            return nil
        }
    }
}

extension [ProjectCard] {
    fileprivate func containsCard(note: String) -> Bool {
        self.contains { $0.note == note }
    }

    fileprivate func firstCard(note: String) -> Self.Element? {
        self.first { $0.note == note }
    }
}
