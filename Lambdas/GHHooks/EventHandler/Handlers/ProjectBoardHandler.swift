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

    /// Yes, send the raw url is the "note" of the card. GitHub will take care of properly showing it.
    /// If you send customized text instead, the card won't be recognized as a issue-card.
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
            try await self.moveOrCreate(targetColumn: .toDo, in: project)
        }
    }

    func onUnlabeled() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        let possibleUnlabeledProjects = Project.allCases.filter { !relatedProjects.contains($0) }
        for project in Set(possibleUnlabeledProjects) {
            for column in Project.Column.allCases {
                let cards = try await self.getCards(in: project.columnID(of: column))
                if let card = cards.firstCard(note: note) {
                    try await self.delete(cardID: card.id)
                }
            }
        }
    }

    func onAssigned() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        for project in Set(relatedProjects) {
            try await self.moveOrCreate(targetColumn: .inProgress, in: project)
        }
    }

    func onUnassigned() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        try await self.moveOrCreateInToDoOrInProgress(relatedProjects: relatedProjects)
    }

    func onClosed() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        switch self.issue.state {
        case "closed":
            for project in Set(relatedProjects) {
                try await self.moveOrCreate(targetColumn: .done, in: project)
            }
        case "open":
            try await self.moveOrCreateInToDoOrInProgress(relatedProjects: relatedProjects)
        default: break
        }
    }

    func onReopened() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        try await self.moveOrCreateInToDoOrInProgress(relatedProjects: relatedProjects)
    }

    private func moveOrCreateInToDoOrInProgress(relatedProjects: [Project]) async throws {
        if (self.issue.assignees ?? []).isEmpty {
            for project in Set(relatedProjects) {
                try await self.moveOrCreate(targetColumn: .toDo, in: project)
            }
        } else {
            for project in Set(relatedProjects) {
                try await self.moveOrCreate(targetColumn: .inProgress, in: project)
            }
        }
    }

    func createCard(columnID: Int) async throws {
        let response = try await self.context.githubClient.projects_create_card(.init(
            path: .init(column_id: columnID),
            body: .json(.case1(.init(note: self.note)))
        ))

        guard case .created = response else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    func move(toColumnID columnID: Int, cardID: Int) async throws {
        let response = try await self.context.githubClient.projects_move_card(.init(
            path: .init(card_id: cardID),
            body: .json(.init(position: "top", column_id: columnID))
        ))

        guard case .created = response else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    func delete(cardID: Int) async throws {
        let response = try await self.context.githubClient.projects_delete_card(.init(
            path: .init(card_id: cardID)
        ))

        guard case .noContent = response else {
            throw Errors.httpRequestFailed(response: response)
        }
    }

    func getCards(in columnID: Int) async throws -> [ProjectCard] {
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

    private func moveOrCreate(targetColumn: Project.Column, in project: Project) async throws {
        func cards(column: Project.Column) async throws -> [ProjectCard] {
            try await self.getCards(in: project.columnID(of: column))
        }

        func move(cardID: Int) async throws {
            try await self.move(toColumnID: project.columnID(of: targetColumn), cardID: cardID)
        }

        let otherColumns = Project.Column.allCases.filter { $0 != targetColumn }

        var alreadyMoved = false
        for column in otherColumns {
            let cards = try await cards(column: column)
            if let card = cards.firstCard(note: note) {
                if alreadyMoved {
                    try await self.delete(cardID: card.id)
                } else {
                    try await move(cardID: card.id)
                    alreadyMoved = true
                }
            }
        }

        if alreadyMoved {
            return
        }

        let cards = try await cards(column: targetColumn)
        if !cards.containsCard(note: self.note) {
            try await self.createCard(columnID: project.columnID(of: targetColumn))
        }
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
