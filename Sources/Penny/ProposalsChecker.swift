import Logging
import DiscordModels
import Models
import Foundation

actor ProposalsChecker {

    struct Storage: Sendable, Codable {
        var previousProposals: [Proposal] = []
        var queuedProposals: [QueuedProposal] = []
    }

    var storage = Storage()

    /// The minimum time to wait before sending a queued-proposal
    var queuedProposalsWaitTime: Double = 29 * 60

    let logger = Logger(label: "ProposalsChecker")

    var proposalsService: (any ProposalsService)!
    var discordService: DiscordService {
        DiscordService.shared
    }

    static let shared = ProposalsChecker()

    private init() { }

    func initialize(proposalsService: any ProposalsService) {
        self.proposalsService = proposalsService
    }

    nonisolated func run() {
        Task {
            try await Task.sleep(for: .seconds(60)) /// 1 min
            do {
                try await self.check()
                try await Task.sleep(for: .seconds(60 * 14)) /// 14 mins
            } catch {
                logger.report("Couldn't check proposals", error: error)
            }
            self.run()
        }
    }

    func check() async throws {
        let proposals = try await self.proposalsService.list()

        if self.storage.previousProposals.isEmpty {
            self.storage.previousProposals = proposals
            return
        }

        /// Queue newly-added proposals
        let currentIds = Set(self.storage.previousProposals.map(\.id))
        let (olds, news) = proposals.divided({ currentIds.contains($0.id) })

        for new in news {
            if let existingIdx = self.storage.queuedProposals.firstIndex(
                where: { $0.proposal.id == new.id }
            ) {
                self.storage.queuedProposals[existingIdx].updatedAt = Date()
                self.storage.queuedProposals[existingIdx].proposal = new
                logger.debug("A new proposal will be delayed", metadata: ["id": .string(new.id)])
            } else {
                self.storage.queuedProposals.append(.init(
                    firstKnownStateBeforeQueue: nil,
                    updatedAt: Date(),
                    proposal: new
                ))
                logger.debug("A new proposal was queued", metadata: ["id": .string(new.id)])
            }
        }

        /// Queue proposals with change of status
        let previousStates = Dictionary(
            self.storage.previousProposals.map({ ($0.id, $0.status.state) }),
            uniquingKeysWith: { l, _ in l }
        )
        let updatedProposals = olds.filter {
            previousStates[$0.id] != $0.status.state
        }

        for updated in updatedProposals {
            guard let previousState = previousStates[updated.id] else { continue }

            if let existingIdx = self.storage.queuedProposals.firstIndex(
                where: { $0.proposal.id == updated.id }
            ) {
                self.storage.queuedProposals[existingIdx].updatedAt = Date()
                self.storage.queuedProposals[existingIdx].proposal = updated
                logger.debug("An updated proposal will be delayed", metadata: [
                    "id": .string(updated.id)
                ])
            } else {
                self.storage.queuedProposals.append(.init(
                    firstKnownStateBeforeQueue: previousState,
                    updatedAt: Date(),
                    proposal: updated
                ))
                logger.debug("An updated proposal was queued", metadata: [
                    "id": .string(updated.id)
                ])
            }
        }

        /// Send the queued-proposals that are ready
        var sentProposalUUIDs = [UUID]()
        for queuedProposal in self.storage.queuedProposals {
            /// `storage.queuedProposalsWaitTime` seconds old == ready to send
            let oldDate = Date().addingTimeInterval(-self.queuedProposalsWaitTime)
            guard queuedProposal.updatedAt < oldDate else { continue }

            let proposal = queuedProposal.proposal

            let payload: Payloads.CreateMessage
            if let previousState = queuedProposal.firstKnownStateBeforeQueue {
                payload = await makePayloadForUpdatedProposal(
                    proposal,
                    previousState: previousState
                )
            } else {
                payload = await makePayloadForNewProposal(proposal)
            }

            await self.send(proposal: proposal, payload: payload)
            sentProposalUUIDs.append(queuedProposal.uuid)
        }

        /// Remove the sent queued-proposals
        self.storage.queuedProposals.removeAll(where: { sentProposalUUIDs.contains($0.uuid) })

        /// Update the saved proposals
        self.storage.previousProposals = proposals
    }

    private func send(proposal: Proposal, payload: Payloads.CreateMessage) async {
        if Task.isCancelled { return }
        /// Send the message, make sure it is successfully sent
        let response = await discordService.sendMessage(
            channelId: Constants.Channels.proposals.id,
            payload: payload
        )
        guard let message = try? response?.decode() else { return }
        /// Create a thread on top of the message
        let name = "Discuss \(proposal.id): \(proposal.title.sanitized())"
            .truncate(ifLongerThan: 100)
        await discordService.createThreadFromMessage(
            channelId: message.channel_id,
            messageId: message.id,
            payload: .init(
                name: name,
                auto_archive_duration: .threeDays
            )
        )
        /// "Publish" the message to other announcement-channel subscribers
        await discordService.crosspostMessage(
            channelId: message.channel_id,
            messageId: message.id
        )
    }

    private func makePayloadForNewProposal(_ proposal: Proposal) async -> Payloads.CreateMessage {
        let titleState = proposal.status.state.titleDescription
        let descriptionState = proposal.status.state.UIDescription
        let title = "[\(proposal.id.sanitized())] \(titleState): \(proposal.title.sanitized())"

        let summary = proposal.summary
            .replacingOccurrences(of: "\n", with: " ")
            .sanitized()
            .truncate(ifLongerThan: 2_048)

        let authors = proposal.authors
            .filter(\.isRealPerson)
            .map { $0.makeStringForDiscord() }
            .joined(separator: ", ")
        let authorsString = authors.isEmpty ? "" : "\n**Authors:** \(authors)"

        let reviewManager = proposal.reviewManager.isRealPerson
        ? proposal.reviewManager.makeStringForDiscord()
        : nil
        let reviewManagerString = reviewManager.map({ "\n**Review Manager:** \($0)" }) ?? ""

        return .init(
            embeds: [.init(
                title: title.truncate(ifLongerThan: 256),
                description: """
                > \(summary)

                **Status: \(descriptionState)**
                \(authorsString)
                \(reviewManagerString)
                """,
                color: proposal.status.state.color
            )],
            components: await makeComponents(proposal: proposal)
        )
    }

    private func makePayloadForUpdatedProposal(
        _ proposal: Proposal,
        previousState: Proposal.Status.State
    ) async -> Payloads.CreateMessage {

        let titleState = proposal.status.state.titleDescription
        let descriptionState = proposal.status.state.UIDescription
        let title = "[\(proposal.id.sanitized())] \(titleState): \(proposal.title.sanitized())"

        let summary = proposal.summary
            .replacingOccurrences(of: "\n", with: " ")
            .sanitized()
            .truncate(ifLongerThan: 2_048)

        let authors = proposal.authors
            .filter(\.isRealPerson)
            .map { $0.makeStringForDiscord() }
            .joined(separator: ", ")
        let authorsString = authors.isEmpty ? "" : "\n**Authors:** \(authors)"

        let reviewManager = proposal.reviewManager.isRealPerson
        ? proposal.reviewManager.makeStringForDiscord()
        : nil
        let reviewManagerString = reviewManager.map({ "\n**Review Manager:** \($0)" }) ?? ""

        return .init(
            embeds: [.init(
                title: title.truncate(ifLongerThan: 256),
                description: """
                > \(summary)

                **Status:** \(previousState.UIDescription) -> **\(descriptionState)**
                \(authorsString)
                \(reviewManagerString)
                """,
                color: proposal.status.state.color
            )],
            components: await makeComponents(proposal: proposal)
        )
    }

    private func makeComponents(proposal: Proposal) async -> [Interaction.ActionRow] {
        let link = proposal.link.sanitized()
        if link.count < 4 { return [] }
        let githubProposalsPrefix = "https://github.com/apple/swift-evolution/blob/main/proposals/"
        let fullGithubLink = githubProposalsPrefix + link
        
        var buttons: [Interaction.ActionRow] = [[
            .button(.init(label: "Proposal", url: fullGithubLink)),
        ]]
        
        if let forumPostLink = await findForumPostLink(link: fullGithubLink) {
            buttons[0].components.append(
                .button(.init(label: "Forum Post", url: forumPostLink))
            )
        }
        
        if let searchLink = makeForumSearchLink(proposal: proposal) {
            buttons[0].components.append(
                .button(.init(label: "Related Posts", url: searchLink))
            )
        }
        
        return buttons
    }

    private func findForumPostLink(link: String) async -> String? {
        let content: String
        do {
            content = try await self.proposalsService.getProposalContent(link: link)
        } catch {
            logger.error("Could not fetch proposal content", metadata: [
                "link": .string(link),
                "error": "\(error)"
            ])
            return nil
        }
        if let latestLink = content
            .split(whereSeparator: \.isNewline)
            .first(where: { $0.hasPrefix("* Review:") })?
            .split(separator: "(")
            .flatMap({ $0.split(separator: ")") })
            .reversed()
            .first(where: { $0.starts(with: "https://") })
            .map(String.init) {
            return latestLink
        } else {
            logger.warning("Couldn't find forums link for proposal", metadata: [
                "link": .string(link),
                "content": .string(content)
            ])
            return nil
        }
    }

    private func makeForumSearchLink(proposal: Proposal) -> String? {
        let title = proposal.title.sanitized()
        guard !title.isEmpty else { return nil }
        let rawQuery = title + " #evolution"
        guard let query = rawQuery.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) else {
            logger.warning("Couldn't url-encode forum-search queries", metadata: [
                "rawQuery": .string(rawQuery)
            ])
            return nil
        }
        let link = "https://forums.swift.org/search?q=\(query)"
        return link
    }

    func consumeCachesStorageData(_ storage: Storage) {
        self.storage.previousProposals = storage.previousProposals
        self.storage.queuedProposals = storage.queuedProposals
    }

    func getCachedDataForCachesStorage() -> Storage {
        return self.storage
    }

#if DEBUG
    func _tests_setQueuedProposalsWaitTime(to amount: Double) {
        self.queuedProposalsWaitTime = amount
    }
#endif
}

private extension String {
    func sanitized() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\/"#, with: "/") /// Un-escape
    }

    func truncate(ifLongerThan max: Int) -> String {
        let scalars = self.unicodeScalars
        if scalars.count > max {
            /// `scalars.count - max` makes the text as long as the limit.
            /// `+ 3` is for the extra `...` that is added.
            return String(scalars.dropLast(scalars.count - max + 3)) + "..."
        } else {
            return self
        }
    }
}

private extension Proposal.User {
    var isRealPerson: Bool {
        !["", "TBD", "N/A"].contains(self.name.sanitized())
    }

    func makeStringForDiscord() -> String {
        let link = link.sanitized()
        let name = name.sanitized()
        if link.isEmpty {
            return name
        } else {
            return "[\(name)](\(link))"
        }
    }
}

struct QueuedProposal: Codable {
    let uuid: UUID
    let firstKnownStateBeforeQueue: Proposal.Status.State?
    var updatedAt: Date
    var proposal: Proposal

    init(
        uuid: UUID = UUID(),
        firstKnownStateBeforeQueue: Proposal.Status.State?,
        updatedAt: Date,
        proposal: Proposal
    ) {
        self.uuid = uuid
        self.firstKnownStateBeforeQueue = firstKnownStateBeforeQueue
        self.updatedAt = updatedAt
        self.proposal = proposal
    }
}

// MARK: - +Proposal
private extension Proposal.Status.State {
    var color: DiscordColor {
        switch self {
        case .accepted: return .green
        case .activeReview: return .orange
        case .implemented: return .blue
        case .previewing: return .lightGreen
        case .rejected: return .red
        case .returnedForRevision: return .purple
        case .withdrawn: return .brown
        case .unknown: return .init(value: 0)!
        }
    }

    var UIDescription: String {
        switch self {
        case .accepted: return "Accepted"
        case .activeReview: return "Active Review"
        case .implemented: return "Implemented"
        case .previewing: return "Previewing"
        case .rejected: return "Rejected"
        case .returnedForRevision: return "Returned For Revision"
        case .withdrawn: return "Withdrawn"
        case let .unknown(unknown): return String(unknown.dropFirst().capitalized)
        }
    }

    var titleDescription: String {
        switch self {
        case .activeReview: return "In Active Review"
        default: return self.UIDescription
        }
    }
}

// MARK: - Proposal
struct Proposal: Sendable, Codable {

    struct User: Sendable, Codable {
        let link: String
        let name: String
    }

    struct Status: Sendable, Codable {

        enum State: RawRepresentable, Equatable, Sendable, Codable {
            case accepted
            case activeReview
            case implemented
            case previewing
            case rejected
            case returnedForRevision
            case withdrawn
            case unknown(String)

            var rawValue: String {
                switch self {
                case .accepted: return ".accepted"
                case .activeReview: return ".activeReview"
                case .implemented: return ".implemented"
                case .previewing: return ".previewing"
                case .rejected: return ".rejected"
                case .returnedForRevision: return ".returnedForRevision"
                case .withdrawn: return ".withdrawn"
                case let .unknown(unknown): return unknown
                }
            }

            init? (rawValue: String) {
                switch rawValue {
                case ".accepted": self = .accepted
                case ".activeReview": self = .activeReview
                case ".implemented": self = .implemented
                case ".previewing": self = .previewing
                case ".rejected": self = .rejected
                case ".returnedForRevision": self = .returnedForRevision
                case ".withdrawn": self = .withdrawn
                default:
                    Logger(label: "\(#file):\(#line)").warning(
                        "New unknown case",
                        metadata: ["rawValue": .string(rawValue)]
                    )
                    self = .unknown(rawValue)
                }
            }
        }

        let state: State
        let version: String?
        let end: String?
        let start: String?
    }

    struct TrackingBug: Sendable, Codable {
        let assignee: String
        let id: String
        let link: String
        let radar: String
        let resolution: String
        let status: String
        let title: String
        let updated: String
    }

    struct Warning: Sendable, Codable {
        let kind: String
        let message: String
        let stage: String
    }

    struct Implementation: Sendable, Codable {

        enum Account: RawRepresentable, Sendable, Codable {
            case apple
            case unknown(String)

            var rawValue: String {
                switch self {
                case .apple: return "apple"
                case let .unknown(unknown): return unknown
                }
            }

            init? (rawValue: String) {
                switch rawValue {
                case "apple": self = .apple
                default:
                    Logger(label: "\(#file):\(#line)").warning(
                        "New unknown case",
                        metadata: ["rawValue": .string(rawValue)]
                    )
                    self = .unknown(rawValue)
                }
            }
        }

        enum Repository: RawRepresentable, Sendable, Codable {
            case swift
            case swiftSyntax
            case swiftCorelibsFoundation
            case swiftPackageManager
            case swiftXcodePlaygroundSupport
            case unknown(String)

            var rawValue: String {
                switch self {
                case .swift: return "swift"
                case .swiftSyntax: return "swift-syntax"
                case .swiftCorelibsFoundation: return "swift-corelibs-foundation"
                case .swiftPackageManager: return "swift-package-manager"
                case .swiftXcodePlaygroundSupport: return "swift-xcode-playground-support"
                case let .unknown(unknown): return unknown
                }
            }

            init? (rawValue: String) {
                switch rawValue {
                case "swift": self = .swift
                case "swift-syntax": self = .swiftSyntax
                case "swift-corelibs-foundation": self = .swiftCorelibsFoundation
                case "swift-package-manager": self = .swiftPackageManager
                case "swift-xcode-playground-support": self = .swiftXcodePlaygroundSupport
                default:
                    Logger(label: "\(#file):\(#line)").warning(
                        "New unknown case",
                        metadata: ["rawValue": .string(rawValue)]
                    )
                    self = .unknown(rawValue)
                }
            }
        }

        enum Kind: RawRepresentable, Sendable, Codable {
            case commit
            case pull
            case unknown(String)

            var rawValue: String {
                switch self {
                case .commit: return "commit"
                case .pull: return "pull"
                case let .unknown(unknown): return unknown
                }
            }

            init? (rawValue: String) {
                switch rawValue {
                case "commit": self = .commit
                case "pull": self = .pull
                default:
                    Logger(label: "\(#file):\(#line)").warning(
                        "New unknown case",
                        metadata: ["rawValue": .string(rawValue)]
                    )
                    self = .unknown(rawValue)
                }
            }
        }

        let account: Account
        let id: String
        let repository: Repository
        let type: Kind
    }

    let authors: [User]
    let id: String
    let link: String
    let reviewManager: User
    let sha: String
    let status: Status
    let summary: String
    let title: String
    let trackingBugs: [TrackingBug]?
    let warnings: [Warning]?
    let implementation: [Implementation]?
}
