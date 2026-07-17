import DiscordBM
import GitHubAPI
import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct ProjectBoardHandler {
    let context: HandlerContext
    let action: Issue.Action
    let issue: Issue
    let repo: Repository
    var event: GHEvent {
        self.context.event
    }
    var logger: Logger {
        self.context.logger
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
        guard let removedLabel = self.event.label?.name,
            let knownLabel = Issue.KnownLabel(rawValue: removedLabel),
            let project = Project(label: knownLabel)
        else { return }
        try await self.deleteItem(in: project)
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
        return try self.itemID(from: item.id)
    }

    private func setStatus(itemID: Int, targetColumn: Project.Column, in project: Project) async throws {
        let statusField = try await self.statusField(in: project)
        let optionID = try statusField.optionID(of: targetColumn)
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
                            id: statusField.id,
                            value: .case1(optionID)
                        )
                    ]
                )
            )
        ).ok
    }

    private func statusField(in project: Project) async throws -> StatusField {
        let fields = try await self.context.githubClient.projectsListFieldsForOrg(
            path: .init(
                projectNumber: project.number,
                org: self.org
            ),
            query: .init(perPage: 100)
        ).ok.body.json
        guard
            let field = fields.first(where: { field in
                field.dataType == .singleSelect
                    && field.name.lowercased() == "status"
            })
        else {
            throw ProjectBoardError.statusFieldNotFound(project: project.number)
        }
        return StatusField(field: field)
    }

    /// Finds the project item whose content is this issue, returning its item id if present.
    private func itemID(in project: Project) async throws -> Int? {
        let itemID = try await self._itemID(in: project)
        self.context.logger.debug(
            "Tried to find item for issue in project",
            metadata: [
                "issueNumber": .stringConvertible(self.issue.number),
                "projectName": .string(project.description),
                "projectNumber": .stringConvertible(project.number),
                "itemID": .string(itemID?.description ?? "<nil>"),
            ]
        )
        return itemID
    }

    /// Finds the project item whose content is this issue, returning its item id if present.
    private func _itemID(in project: Project) async throws -> Int? {
        var after: String?
        while true {
            let ok = try await self.context.githubClient.projectsListItemsForOrg(
                path: .init(
                    projectNumber: project.number,
                    org: self.org
                ),
                query: .init(after: after, perPage: 100)
            ).ok
            let items = try ok.body.json
            if let item = items.first(where: { $0.contentNodeID == self.issue.nodeId }) {
                return try self.itemID(from: item.id)
            }
            guard let next = self.nextCursor(fromLinkHeader: ok.headers.link) else {
                return nil
            }
            after = next
        }
    }

    private func itemID(from id: Double) throws -> Int {
        guard let itemID = Int(exactly: id.rounded()) else {
            throw ProjectBoardError.invalidItemID(id)
        }
        return itemID
    }

    private func nextCursor(fromLinkHeader link: String?) -> String? {
        guard let link else { return nil }
        for entry in link.split(separator: ",") {
            guard
                entry.firstRange(of: #"rel="next""#) != nil,
                let afterRange = entry.firstRange(of: "after=")
            else { continue }
            let value = entry[afterRange.upperBound...].prefix { $0 != "&" && $0 != ">" }
            return value.removingPercentEncoding
        }
        return nil
    }
}

private struct StatusField {
    let id: Int
    let optionIDsByNormalizedName: [String: String]

    init(field: Components.Schemas.ProjectsV2Field) {
        self.id = field.id
        var optionIDsByNormalizedName: [String: String] = [:]
        optionIDsByNormalizedName.reserveCapacity(field.options?.count ?? 0)
        for option in field.options ?? [] {
            let key = Self.normalize(option.name.raw)
            if !optionIDsByNormalizedName.keys.contains(key) {
                optionIDsByNormalizedName[key] = option.id
            }
        }
        self.optionIDsByNormalizedName = optionIDsByNormalizedName
    }

    static func normalize(_ name: String) -> String {
        name.lowercased().filter { !$0.isWhitespace }
    }

    func optionID(of column: Project.Column) throws -> String {
        guard let optionID = self.optionIDsByNormalizedName[Self.normalize(column.optionName)] else {
            throw ProjectBoardError.statusOptionNotFound(column: column.optionName)
        }
        return optionID
    }
}

enum ProjectBoardError: Error, CustomStringConvertible {
    case statusFieldNotFound(project: Int)
    case statusOptionNotFound(column: String)
    case invalidItemID(Double)

    var description: String {
        switch self {
        case let .statusFieldNotFound(project):
            return "statusFieldNotFound(project: \(project))"
        case let .statusOptionNotFound(column):
            return "statusOptionNotFound(column: \(column))"
        case let .invalidItemID(id):
            return "invalidItemID(\(id))"
        }
    }
}

private enum Project: String, CaseIterable, CustomStringConvertible {
    case helpWanted
    case beginner

    enum Column: CaseIterable {
        case toDo
        case inProgress
        case done

        var optionName: String {
            switch self {
            case .toDo:
                return "Todo"
            case .inProgress:
                return "In Progress"
            case .done:
                return "Done"
            }
        }
    }

    var description: String {
        switch self {
        case .helpWanted:
            return "Help Wanted"
        case .beginner:
            return "Beginner"
        }
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
