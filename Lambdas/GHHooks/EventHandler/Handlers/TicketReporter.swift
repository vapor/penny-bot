import DiscordBM
import Shared
#if canImport(FoundationEssentials)
import struct FoundationEssentials.Date
#else
import struct Foundation.Date
#endif

/// Reports opened/edited issues and PRs.
struct TicketReporter {

    enum Configuration {
        static let userIDDenyList: Set<Int> = [ /* dependabot[bot]: */ 49_699_333]
    }

    private static let ticketQueue = SerialProcessor()

    var context: HandlerContext
    let embed: Embed
    let createdAt: Date
    let repoID: Int
    let number: Int
    let authorID: Int
    var ticketKey: String {
        "\(repoID)_\(number)"
    }
    var channel: Constants.Channels {
        .reportingChannel(repoID: repoID, createdAt: createdAt)
    }

    init(
        context: HandlerContext,
        embed: Embed,
        createdAt: Date,
        repoID: Int,
        number: Int,
        authorID: Int
    ) {
        self.context = context
        self.embed = embed
        self.createdAt = createdAt
        self.repoID = repoID
        self.number = number
        self.authorID = authorID

        self.context.logger[metadataKey: "repoID"] = .stringConvertible(repoID)
        self.context.logger[metadataKey: "number"] = .stringConvertible(number)
    }

    func reportCreation() async throws {
        if Configuration.userIDDenyList.contains(authorID) { return }

        let response = try await context.discordClient.createMessage(
            channelId: self.channel.id,
            payload: .init(embeds: [embed])
        ).decode()

        try await context.messageLookupRepo.saveMessageID(
            messageID: response.id.rawValue,
            repoID: repoID,
            number: number
        )
    }

    /// - Parameter requiresPreexistingReport: Requires a report to have already been done about
    /// the ticket. If not, this report process will be aborted.
    func reportEdition(requiresPreexistingReport: Bool) async throws {
        if Configuration.userIDDenyList.contains(authorID) { return }

        let messageID: MessageSnowflake

        do {
            let repoMessageID = try await context.messageLookupRepo.getMessageID(
                repoID: repoID,
                number: number
            )
            messageID = MessageSnowflake(repoMessageID)
            context.logger.debug("Got message ID from Repo", metadata: [
                "messageID": "\(messageID)"
            ])
        } catch let error as DynamoMessageRepo.Errors where error == .unavailable {
            context.logger.debug("Message is unavailable to edit")
            return
        } catch let error as DynamoMessageRepo.Errors where error == .notFound {
            if requiresPreexistingReport {
                context.logger.warning(
                    "Didn't find a message id from the lookup repo, and the report requires a preexisting report"
                )
                return
            }
            context.logger.debug(
                "Didn't find a message id from the lookup repo, will send a new message"
            )

            let response = try await context.discordClient.createMessage(
                channelId: self.channel.id,
                payload: .init(embeds: [embed])
            ).decode()

            try await context.messageLookupRepo.saveMessageID(
                messageID: response.id.rawValue,
                repoID: repoID,
                number: number
            )
            return
        }

        let response = try await context.discordClient.updateMessage(
            channelId: self.channel.id,
            messageId: messageID,
            payload: .init(embeds: [embed])
        )

        switch response.asError() {
        case let .jsonError(jsonError) where jsonError.code == .unknownMessage:
            context.logger.debug(
                "Discord says message id is unknown. Will mark as unavailable in DB.",
                metadata: ["messageID": .stringConvertible(messageID)]
            )
            try await context.messageLookupRepo.markAsUnavailable(
                repoID: repoID,
                number: number
            )
        case let .some(error):
            throw error
        default: break
        }
    }
}

private extension Constants.Channels {
    static func reportingChannel(repoID: Int, createdAt: Date) -> Self {
        /// The change to use `.documentation` was made only after this timestamp.
        if createdAt.timeIntervalSince1970 < 1_696_067_000 {
            return .issuesAndPRs
        } else {
            switch repoID {
            case 64560805:
                return .documentation
            default:
                return .issuesAndPRs
            }
        }
    }
}
