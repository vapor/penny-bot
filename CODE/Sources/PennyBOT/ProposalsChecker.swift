import AsyncHTTPClient
import Logging
import NIOCore
import DiscordModels
import Foundation

actor ProposalsChecker {
    let httpClient: HTTPClient
    let logger = Logger(label: "ProposalsChecker")
    var discordService: DiscordService {
        DiscordService.shared
    }
    var isFirstRound = true
    private var previousProposals = [Proposal]()

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
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
        let proposals = try await self.getProposals()
        /// If it's the first round, we have nothing to compare to
        if isFirstRound {
            self.previousProposals = proposals
            isFirstRound = false
            return
        }

        /// Newly-added proposals
        let currentIds = Set(self.previousProposals.map(\.id))
        let (olds, news) = proposals.divided({ currentIds.contains($0.id) })

        for new in news {
            await discordService.sendMessage(
                /// For testing purposes
                channelId: Constants.logsChannelId,
                payload: makePayloadForNewProposal(new)
            )
        }

        /// Proposals with change of status
        let stateDict = Dictionary(
            self.previousProposals.map({ ($0.id, $0.status.state) }),
            uniquingKeysWith: { l, _ in l }
        )
        let updatedProposals = olds.filter {
            stateDict[$0.id] != $0.status.state
        }

        for updated in updatedProposals {
            await discordService.sendMessage(
                /// For testing purposes
                channelId: Constants.logsChannelId,
                payload: makePayloadForUpdatedProposal(
                    updated,
                    previousState: stateDict[updated.id]! /// Guaranteed to exist
                )
            )
        }

        /// Update the saved proposals
        self.previousProposals = proposals
    }

    private func getProposals() async throws -> [Proposal] {
        let response = try await httpClient.execute(
            .init(url: "https://download.swift.org/swift-evolution/proposals.json"),
            deadline: .now() + .seconds(5)
        )
        let buffer = try await response.body.collect(upTo: 1 << 23) /// 8 MB
        let decoder = JSONDecoder()
        let proposals = try decoder.decode([Proposal].self, from: buffer)
        return proposals
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

        return .init(embeds: [.init(
            title: "New Proposal: \(proposal.title.sanitized())",
            description: """
            > \(proposal.summary.sanitized())

            Status: \(proposal.status.state.UIDescription)
            \(authorsString)
            \(reviewManagerString)
            """,
            color: proposal.status.state.color
        )])
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

        return .init(embeds: [.init(
            title: "Proposal Updated: \(proposal.title.sanitized())",
            description: """
            > \(proposal.summary.sanitized())

            Status: \(previousState.UIDescription) -> \(proposal.status.state.UIDescription)
            \(authorsString)
            \(reviewManagerString)
            """,
            color: proposal.status.state.color
        )])
    }
}

private extension String {
    func sanitized() -> String {
        self.unescaped().trimmed()
    }

    private func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func unescaped() -> String {
        self.replacingOccurrences(of: #"\/"#, with: "/")
    }
}

private struct Proposal: Codable {

    struct User: Codable {
        let link: String
        let name: String

        var isRealPerson: Bool {
            !["", "TBD", "N/A"].contains(self.name.sanitized())
        }

        func makeStringForDiscord() -> String {
            if self.link.isEmpty {
                return self.name.sanitized()
            } else {
                let name = self.name.sanitized()
                let link = self.link.sanitized()
                return "[\(name)](\(link))"
            }
        }
    }

    struct Status: Codable {

        enum State: String, Codable {
            case accepted = ".accepted"
            case activeReview = ".activeReview"
            case implemented = ".implemented"
            case previewing = ".previewing"
            case rejected = ".rejected"
            case returnedForRevision = ".returnedForRevision"
            case withdrawn = ".withdrawn"

            var color: DiscordColor {
                switch self {
                case .accepted: return .green
                case .activeReview: return .orange
                case .implemented: return .blue
                case .previewing: return .init(hex: "#29AB87")!
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

        let state: State
        let version: String?
        let end: String?
        let start: String?
    }

    struct TrackingBug: Codable {
        let assignee: String
        let id: String
        let link: String
        let radar: String
        let resolution: String
        let status: String
        let title: String
        let updated: String
    }

    struct Warning: Codable {
        let kind: String
        let message: String
        let stage: String
    }

    struct Implementation: Codable {

        enum Account: String, Codable {
            case apple = "apple"
        }

        enum Repository: String, Codable {
            case swift = "swift"
            case swiftCorelibsFoundation = "swift-corelibs-foundation"
            case swiftPackageManager = "swift-package-manager"
            case swiftXcodePlaygroundSupport = "swift-xcode-playground-support"
        }

        enum Kind: String, Codable {
            case commit = "commit"
            case pull = "pull"
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
