import Logging
import DiscordModels
import PennyModels
import Foundation

actor ProposalsChecker {
    var previousProposals = [Proposal]()

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
        let proposals = try await self.proposalsService.get()

        if self.previousProposals.isEmpty {
            self.previousProposals = proposals
            return
        }

        /// Report newly-added proposals
        let currentIds = Set(self.previousProposals.map(\.id))
        let (olds, news) = proposals.divided({ currentIds.contains($0.id) })

        for new in news {
            await discordService.sendMessage(
                channelId: Constants.Channels.proposals.id,
                payload: makePayloadForNewProposal(new)
            )
        }

        /// Report proposals with change of status
        let previousStates = Dictionary(
            self.previousProposals.map({ ($0.id, $0.status.state) }),
            uniquingKeysWith: { l, _ in l }
        )
        let updatedProposals = olds.filter {
            previousStates[$0.id] != $0.status.state
        }

        for updated in updatedProposals {
            if let previousState = previousStates[updated.id] {
                await discordService.sendMessage(
                    channelId: Constants.Channels.proposals.id,
                    payload: makePayloadForUpdatedProposal(updated, previousState: previousState)
                )
            }
        }

        /// Update the saved proposals
        self.previousProposals = proposals
    }

    private func makePayloadForNewProposal(_ proposal: Proposal) -> Payloads.CreateMessage {
        let authors = proposal.authors
            .filter(\.isRealPerson)
            .map { $0.makeStringForDiscord() }
            .joined(separator: ", ")
        let authorsString = authors.isEmpty ? "" : "\nAuthors: \(authors)"

        let reviewManager = proposal.reviewManager.isRealPerson
        ? proposal.reviewManager.makeStringForDiscord()
        : nil
        let reviewManagerString = reviewManager.map({ "\nReview Manager: \($0)" }) ?? ""

        let title = "New Proposal: **\(proposal.id.sanitized())** \(proposal.title.sanitized())"

        return .init(
            embeds: [.init(
                title: title.truncate(ifLongerThan: 256),
                description: """
                > \(proposal.summary.sanitized().truncate(ifLongerThan: 2_500))

                Status: **\(proposal.status.state.UIDescription)**
                \(authorsString)
                \(reviewManagerString)
                """,
                color: proposal.status.state.color
            )],
            components: makeComponents(link: proposal.link)
        )
    }

    private func makePayloadForUpdatedProposal(
        _ proposal: Proposal,
        previousState: Proposal.Status.State
    ) -> Payloads.CreateMessage {
        let authors = proposal.authors
            .filter(\.isRealPerson)
            .map { $0.makeStringForDiscord() }
            .joined(separator: ", ")
        let authorsString = authors.isEmpty ? "" : "\nAuthors: \(authors)"

        let reviewManager = proposal.reviewManager.isRealPerson
        ? proposal.reviewManager.makeStringForDiscord()
        : nil
        let reviewManagerString = reviewManager.map({ "\nReview Manager: \($0)" }) ?? ""

        let title = "Proposal Updated: **\(proposal.id.sanitized())** \(proposal.title.sanitized())"

        return .init(
            embeds: [.init(
                title: title.truncate(ifLongerThan: 256),
                description: """
                > \(proposal.summary.sanitized().truncate(ifLongerThan: 2_500))

                Status: **\(previousState.UIDescription)** -> **\(proposal.status.state.UIDescription)**
                \(authorsString)
                \(reviewManagerString)
                """,
                color: proposal.status.state.color
            )],
            components: makeComponents(link: proposal.link)
        )
    }

    private func makeComponents(link: String) -> [Interaction.ActionRow] {
        let link = link.sanitized()
        if link.isEmpty {
            return []
        } else {
            return [[.button(.init(
                style: .link,
                label: "Open on Github",
                url: link
            ))]]
        }
    }

#if DEBUG
    func _tests_setPreviousProposals(to proposals: [Proposal]) {
        self.previousProposals = proposals
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
            return String(scalars.dropLast(scalars.count - max).dropLast(4)) + " ..."
        } else {
            return self
        }
    }
}

extension Proposal.User {
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

extension Proposal.Status.State {
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
}
