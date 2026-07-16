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

    var org: String {
        self.repo.owner.login
    }

    init(context: HandlerContext, action: Issue.Action, issue: Issue) throws {
        self.context = context
        self.action = action
        self.issue = issue
        self.repo = try self.context.event.repository.requireValue()
    }

    func handle() async throws {
        /// Ignore events on closed issues, if the even isn't the closed-event itself.
        if self.issue.isClosed && self.action != .closed { return }

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
        try await self.moveOrCreateInToDoOrInProgress(relatedProjects: relatedProjects)
    }

    func onUnlabeled() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        let possibleUnlabeledProjects = Project.allCases.filter { !relatedProjects.contains($0) }
        for project in Set(possibleUnlabeledProjects) {
            try await self.deleteItem(in: project)
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
        if self.issue.stateReason == .notPlanned {
            for project in Set(relatedProjects) {
                try await self.deleteItem(in: project)
            }
        } else {
            for project in Set(relatedProjects) {
                try await self.moveOrCreate(targetColumn: .done, in: project)
            }
        }
    }

    func onReopened() async throws {
        let relatedProjects = self.issue.knownLabels.compactMap(Project.init(label:))
        try await self.moveOrCreateInToDoOrInProgress(relatedProjects: relatedProjects)
    }

    private func moveOrCreateInToDoOrInProgress(relatedProjects: [Project]) async throws {
        for project in Set(relatedProjects) {
            let targetColumn: Project.Column = issue.hasAssignees ? .inProgress : .toDo
            try await self.moveOrCreate(targetColumn: targetColumn, in: project)
        }
    }

    /// The item id is an issue/pull-request that is already in the project, or the item
    /// that gets created if the issue/pull-request isn't in the project yet.
    private func moveOrCreate(targetColumn: Project.Column, in project: Project) async throws {
        let itemID: Int
        if let existingItemID = try await self.itemID(in: project) {
            itemID = existingItemID
        } else {
            itemID = try await self.createItem(in: project)
        }
        try await self.setStatus(itemID: itemID, targetColumn: targetColumn, in: project)
    }

    private func deleteItem(in project: Project) async throws {
        guard let itemID = try await self.itemID(in: project) else { return }
        _ = try await self.context.githubClient.projectsDeleteItemForOrg(
            path: .init(
                projectNumber: project.number,
                org: self.org,
                itemId: itemID
            )
        ).noContent
    }

    private func createItem(in project: Project) async throws -> Int {
        let item = try await self.context.githubClient.projectsAddItemForOrg(
            path: .init(
                org: self.org,
                projectNumber: project.number
            ),
            body: .json(
                .init(
                    _type: .issue,
                    owner: self.org,
                    repo: self.repo.name,
                    number: self.issue.number
                )
            )
        ).created.body.json
        return Int(item.id)
    }

    private func setStatus(itemID: Int, targetColumn: Project.Column, in project: Project) async throws {
        _ = try await self.context.githubClient.projectsUpdateItemForOrg(
            path: .init(
                projectNumber: project.number,
                org: self.org,
                itemId: itemID
            ),
            body: .json(
                .init(
                    fields: [
                        .init(
                            id: project.statusFieldID,
                            value: .case1(project.columnID(of: targetColumn))
                        )
                    ]
                )
            )
        ).ok
    }

    /// Finds the project item whose content is this issue, returning its item id if present.
    private func itemID(in project: Project) async throws -> Int? {
        let items = try await self.context.githubClient.projectsListItemsForOrg(
            path: .init(
                projectNumber: project.number,
                org: self.org
            ),
            query: .init(perPage: 100)
        ).ok.body.json
        let item = items.first { item in
            item.contentNodeID == self.issue.nodeId
        }
        return item.map { Int($0.id) }
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

    /// The project's number, as seen in its URL.
    var number: Int {
        switch self {
        case .helpWanted:
            return 13
        case .beginner:
            return 14
        }
    }

    /// The id of the project's `Status` single-select field.
    var statusFieldID: Int {
        switch self {
        case .helpWanted:
            return 129_033_232
        case .beginner:
            return 129_033_282
        }
    }

    /// The id of the `Status` field's option that corresponds to the column.
    func columnID(of column: Column) -> String {
        switch self {
        case .helpWanted:
            switch column {
            case .toDo:
                return "42be116a"
            case .inProgress:
                return "3bb65142"
            case .done:
                return "0a70d603"
            }
        case .beginner:
            switch column {
            case .toDo:
                return "069550a6"
            case .inProgress:
                return "5fea3daa"
            case .done:
                return "0934de2f"
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

extension Issue {
    fileprivate var isClosed: Bool {
        self.state == "closed"
    }

    fileprivate var hasAssignees: Bool {
        !(self.assignees ?? []).isEmpty
    }
}
