import Logging
import ServiceLifecycle
import Markdown
import DiscordModels
import Models
import EvolutionMetadataModel
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

actor EvolutionChecker: Service {

    struct Storage: Sendable, Codable {
        var previousProposals: [Proposal] = []
        var queuedProposals: [QueuedProposal] = []
    }

    var storage = Storage()

    var reportedProposalIDsThatContainErrors: Set<String> = []

    /// The minimum time to wait before sending a queued-proposal
    let queuedProposalsWaitTime: Double

    let evolutionService: any EvolutionService
    let discordService: DiscordService
    let logger = Logger(label: "EvolutionChecker")

    init(
        evolutionService: any EvolutionService,
        discordService: DiscordService,
        queuedProposalsWaitTime: Double = 29 * 60
    ) {
        self.evolutionService = evolutionService
        self.discordService = discordService
        self.queuedProposalsWaitTime = queuedProposalsWaitTime
    }

    func run() async throws {
        if Task.isCancelled { return }
        do {
            try await self.check()
            try await Task.sleep(for: .seconds(60 * 15)) /// 15 mins
        } catch {
            logger.report("Couldn't check proposals", error: error)
            try await Task.sleep(for: .seconds(60 * 5))
        }
        try await self.run()
    }

    private func check() async throws {
        let proposals = try await evolutionService.list()

        if self.storage.previousProposals.isEmpty {
            self.storage.previousProposals = proposals
            return
        }

        let proposalIDsWithError = proposals.filter {
            !($0.errors ?? []).isEmpty
        }.map(\.id)
        switch proposalIDsWithError.isEmpty {
        case false:
            let allAreAlreadyReported = self.reportedProposalIDsThatContainErrors
                .isSuperset(of: proposalIDsWithError)
            self.reportedProposalIDsThatContainErrors.formUnion(proposalIDsWithError)

            self.logger.log(
                level: allAreAlreadyReported ? .debug : .warning,
                "Will not continue checking proposals because there are errors in some of them",
                metadata: [
                    "proposalsWithError": .stringConvertible(proposalIDsWithError)
                ]
            )

            return
        case true:
            self.reportedProposalIDsThatContainErrors.removeAll()
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
            self.storage.previousProposals.map({ ($0.id, $0.status) }),
            uniquingKeysWith: { l, _ in l }
        )
        let updatedProposals = olds.filter {
            previousStates[$0.id] != $0.status
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
            channelId: Constants.Channels.evolution.id,
            payload: payload
        )
        guard let message = try? response?.decode() else { return }
        /// Create a thread on top of the message
        let name = "Discuss \(proposal.id): \(proposal.title.sanitized())".unicodesPrefix(100)
        await discordService.createThreadFromMessage(
            channelId: message.channel_id,
            messageId: message.id,
            payload: .init(
                name: name,
                auto_archive_duration: .threeDays
            )
        )
    }

    private func makePayloadForNewProposal(_ proposal: Proposal) async -> Payloads.CreateMessage {
        let stateTitle = proposal.status.titleDescription.map { $0 + ": " } ?? ""
        let stateDescription = proposal.status.UIDescription
        let title = "[\(proposal.id.sanitized())] \(stateTitle)\(proposal.title.sanitized())"

        let summary = makeSummary(proposal: proposal)

        let upcomingFeatureFlag = proposal.upcomingFeatureFlag.map {
            "\n**Upcoming Feature Flag:** \($0.flag)"
        } ?? ""

        let authors = proposal.authors
            .filter(\.isRealPerson)
            .map { $0.makeStringForDiscord() }
            .joined(separator: ", ")
            .nilIfEmpty
        let authorsString = authors.map({ "\n**Author(s):** \($0)" }) ?? ""

        let reviewManagers = proposal.reviewManagers
            .filter(\.isRealPerson)
            .map { $0.makeStringForDiscord() }
            .joined(separator: ", ")
            .nilIfEmpty
        let reviewManagersString = reviewManagers.map({ "\n**Review Manager(s):** \($0)" }) ?? ""

        let link = proposal.link.sanitized()
        var proposalLink: String?
        if link.count > 10 {
            proposalLink = "https://github.com/apple/swift-evolution/blob/main/proposals/\(link)"
        }

        var status = ""
        if let current = stateDescription {
            status = """

            **Status: \(current)**
            """
        }

        return .init(
            embeds: [.init(
                title: title.unicodesPrefix(256),
                description: """
                > \(summary)
                \(status)
                \(upcomingFeatureFlag)
                \(authorsString)
                \(reviewManagersString)
                """.replaceTripleNewlinesWithDoubleNewlines(),
                url: proposalLink,
                color: proposal.status.color
            )],
            components: await makeComponents(proposal: proposal)
        )
    }

    private func makePayloadForUpdatedProposal(
        _ proposal: Proposal,
        previousState: Proposal.Status
    ) async -> Payloads.CreateMessage {

        let stateTitle = proposal.status.titleDescription.map { $0 + ": " } ?? ""
        let stateDescription = proposal.status.UIDescription
        let title = "[\(proposal.id.sanitized())] \(stateTitle)\(proposal.title.sanitized())"

        let summary = makeSummary(proposal: proposal)

        let upcomingFeatureFlag = proposal.upcomingFeatureFlag.map {
            "\n**Upcoming Feature Flag:** \($0.flag)"
        } ?? ""

        let authors = proposal.authors
            .filter(\.isRealPerson)
            .map { $0.makeStringForDiscord() }
            .joined(separator: ", ")
            .nilIfEmpty
        let authorsString = authors.map({ "\n**Author(s):** \($0)" }) ?? ""

        let reviewManagers = proposal.reviewManagers
            .filter(\.isRealPerson)
            .map { $0.makeStringForDiscord() }
            .joined(separator: ", ")
            .nilIfEmpty
        let reviewManagersString = reviewManagers.map({ "\n**Review Manager(s):** \($0)" }) ?? ""

        let link = proposal.link.sanitized()
        var proposalLink: String?
        if link.count > 10 {
            proposalLink = "https://github.com/apple/swift-evolution/blob/main/proposals/\(link)"
        }

        var status = ""
        if let previous = previousState.UIDescription,
           let new = stateDescription {
            status = """

            **Status:** \(previous) -> **\(new)**
            """
        }

        return .init(
            embeds: [.init(
                title: title.unicodesPrefix(256),
                description: """
                > \(summary)
                \(status)
                \(upcomingFeatureFlag)
                \(authorsString)
                \(reviewManagersString)
                """.replaceTripleNewlinesWithDoubleNewlines(),
                url: proposalLink,
                color: proposal.status.color
            )],
            components: await makeComponents(proposal: proposal)
        )
    }

    private func makeComponents(proposal: Proposal) async -> [Interaction.ActionRow] {
        var buttons: [Interaction.ActionRow] = [[]]

        if let discussion = proposal.discussions.last {
            buttons[0].components.append(
                .button(.init(
                    label: "\(discussion.name.capitalized) Post",
                    url: discussion.link
                ))
            )
        }

        if let link = makeForumSearchLink(proposal: proposal) {
            buttons[0].components.append(
                .button(.init(label: "Related Posts", url: link))
            )
        }

        return buttons
    }

    private func makeForumSearchLink(proposal: Proposal) -> String? {
        let title = proposal.title.sanitized()
        guard !title.isEmpty else { return nil }
        let rawQuery = title + " #evolution"
        let query = rawQuery.urlPathEncoded()
        let link = "https://forums.swift.org/search?q=\(query)"
        return link
    }

    func makeSummary(proposal: Proposal) -> String {
        let document = Document(parsing: proposal.summary)
        var repairer = LinkRepairer(
            relativeTo: "https://github.com/apple/swift-evolution/blob/main/proposals"
        )
        let newMarkup = repairer.visit(document)
        /// Won't be `nil`, but just in case.
        if newMarkup == nil {
            logger.warning("Edited Markup was nil", metadata: ["proposal": "\(proposal)"])
        }
        let newSummary = newMarkup?.format() ?? proposal.summary
        return newSummary
            .replacing("\n", with: " ")
            .sanitized()
            .unicodesPrefix(2_048)
    }

    func consumeCachesStorageData(_ storage: Storage) {
        self.storage = storage
    }

    func getCachedDataForCachesStorage() -> Storage {
        return self.storage
    }
}

private extension String {
    func sanitized() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing(#"\/"#, with: "/") /// Un-escape
    }
}

private extension Proposal.Person {
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

// MARK: - LinkRepairer

/// Edits relative proposal links to absolute links so they look correct on Discord.
struct LinkRepairer: MarkupRewriter {
    let relativeTo: String

    func visitLink(_ link: Link) -> (any Markup)? {
        if let dest = link.destination?.trimmingCharacters(in: .whitespaces),
           !dest.hasPrefix("https://"),
           dest.hasSuffix(".md") {
            /// It's a relative .md link like "0400-init-accessors.md".
            /// We make it absolute.
            var link = link
            link.destination = "\(relativeTo)/\(dest)"
            return link
        }
        return link
    }
}

// MARK: - QueuedProposal
struct QueuedProposal: Sendable, Codable {
    let uuid: UUID
    let firstKnownStateBeforeQueue: Proposal.Status?
    var updatedAt: Date
    var proposal: Proposal

    init(
        uuid: UUID = UUID(),
        firstKnownStateBeforeQueue: Proposal.Status?,
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
private extension Proposal.Status {
    var color: DiscordColor {
        switch self {
        case .accepted: return .green
        case .acceptedWithRevisions: return .green(scheme: .dark)
        case .activeReview: return .orange
        case .scheduledForReview: return .yellow
        case .awaitingReview: return .yellow
        case .implemented: return .blue
        case .previewing: return .teal
        case .rejected: return .red
        case .returnedForRevision: return .purple
        case .withdrawn: return .brown
        case .error: return .gray(level: .level6, scheme: .dark)
        }
    }

    var UIDescription: String? {
        switch self {
        case .accepted: return "Accepted"
        case .acceptedWithRevisions: return "Accepted With Revisions"
        case .activeReview: return "Active Review"
        case .scheduledForReview: return "Scheduled For Review"
        case .awaitingReview: return "Awaiting Review"
        case .implemented: return "Implemented"
        case .previewing: return "Previewing"
        case .rejected: return "Rejected"
        case .returnedForRevision: return "Returned For Revision"
        case .withdrawn: return "Withdrawn"
        case .error: return nil
        }
    }

    var titleDescription: String? {
        switch self {
        case .activeReview: return "In Active Review"
        default: return self.UIDescription
        }
    }
}

private extension Collection {
    var nilIfEmpty: Self? {
        self.isEmpty ? nil : self
    }
}

private extension String {
    func replaceTripleNewlinesWithDoubleNewlines() -> String {
        self.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
}
