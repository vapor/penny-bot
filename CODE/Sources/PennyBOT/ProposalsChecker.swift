import Logging
import DiscordModels
import PennyModels
import Foundation

actor ProposalsChecker {
    var previousProposals = [Proposal]()

    var queuedProposals = [QueuedProposal]()
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
            do {
                try await self.check()
                try await Task.sleep(for: .seconds(60 * 15)) /// 15 mins
            } catch {
                logger.report("Couldn't check proposals", error: error)
            }
            self.run()
        }
    }

    func check() async throws {
        let proposals = try await self.proposalsService.list()

        if self.previousProposals.isEmpty {
            self.previousProposals = proposals
            return
        }

        /// Queue newly-added proposals
        let currentIds = Set(self.previousProposals.map(\.id))
        let (olds, news) = proposals.divided({ currentIds.contains($0.id) })

        for new in news {
            if let existingIdx = self.queuedProposals.firstIndex(
                where: { $0.proposal.id == new.id }
            ) {
                self.queuedProposals[existingIdx].updatedAt = Date()
                self.queuedProposals[existingIdx].proposal = new
                logger.notice("A new proposal will be delayed", metadata: ["id": .string(new.id)])
            } else {
                self.queuedProposals.append(.init(
                    firstKnownStateBeforeQueue: nil,
                    updatedAt: Date(),
                    proposal: new
                ))
                logger.notice("A new proposal was queued", metadata: ["id": .string(new.id)])
            }
        }

        /// Queue proposals with change of status
        let previousStates = Dictionary(
            self.previousProposals.map({ ($0.id, $0.status.state) }),
            uniquingKeysWith: { l, _ in l }
        )
        let updatedProposals = olds.filter {
            previousStates[$0.id] != $0.status.state
        }

        for updated in updatedProposals {
            guard let previousState = previousStates[updated.id] else { continue }

            if let existingIdx = self.queuedProposals.firstIndex(
                where: { $0.proposal.id == updated.id }
            ) {
                self.queuedProposals[existingIdx].updatedAt = Date()
                self.queuedProposals[existingIdx].proposal = updated
                logger.notice("An updated proposal will be delayed", metadata: [
                    "id": .string(updated.id)
                ])
            } else {
                self.queuedProposals.append(.init(
                    firstKnownStateBeforeQueue: previousState,
                    updatedAt: Date(),
                    proposal: updated
                ))
                logger.notice("An updated proposal was queued", metadata: [
                    "id": .string(updated.id)
                ])
            }
        }

        /// Send the queued-proposals that are ready
        var sentProposalUUIDs = [UUID]()
        for queuedProposal in self.queuedProposals {
            /// `queuedProposalsWaitTime` seconds old == ready to send
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
        self.queuedProposals.removeAll(where: { sentProposalUUIDs.contains($0.uuid) })

        /// Update the saved proposals
        self.previousProposals = proposals
    }

    private func send(proposal: Proposal, payload: Payloads.CreateMessage) async {
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
        if link.isEmpty {
            return []
        } else {
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
            logger.warning("Could not find a Swift forums link for proposal", metadata: [
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
        ) else { return nil }
        let link = "https://forums.swift.org/search?q=\(query)"
        return link
    }

#if DEBUG
    func _tests_setPreviousProposals(to proposals: [Proposal]) {
        self.previousProposals = proposals
    }

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

struct QueuedProposal {
    let uuid = UUID()
    let firstKnownStateBeforeQueue: Proposal.Status.State?
    var updatedAt: Date
    var proposal: Proposal
}

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
        }
    }

    var titleDescription: String {
        switch self {
        case .activeReview: return "In Active Review"
        default: return self.UIDescription
        }
    }
}
