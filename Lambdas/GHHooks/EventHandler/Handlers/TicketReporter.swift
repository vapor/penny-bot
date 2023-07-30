import DiscordBM
import struct Foundation.Date

/// Reports opened/edited issues and PRs.
struct TicketReporter {

    enum Errors: Error, CustomStringConvertible {
        case tooManyMatchingMessagesFound(matchingURL: String, messages: [DiscordChannel.Message])

        var description: String {
            switch self {
            case let .tooManyMatchingMessagesFound(matchingURL, messages):
                return "tooManyMatchingMessagesFound(matchingURL: \(matchingURL), messages: \(messages))"
            }
        }
    }
    
    let context: HandlerContext
    let embed: Embed
    let repoID: Int
    let number: Int
    /// A ticket could be a PR/Issue or stuff like that.
    let ticketCreatedAt: Date

    let firstReportDate = Date(timeIntervalSince1970: 1688436000)

    func reportCreation() async throws {
        let response = try await context.discordClient.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [embed])
        ).decode()
        try await context.messageLookupRepo.saveMessageID(
            messageID: response.id.rawValue,
            repoID: repoID,
            number: number
        )
    }

    func reportEdition() async throws {
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
        } catch let error as DynamoMessageRepo.Errors where error == .notFound {
            context.logger.debug(
                "Didn't find a message id from the lookup repo, will send a new message",
                metadata: [
                    "repoID": .stringConvertible(repoID),
                    "number": .stringConvertible(number),
                ]
            )

            /// Report to Discord since this is unexpected.
            if ticketCreatedAt > firstReportDate {
                try await context.discordClient.createMessage(
                    channelId: Constants.Channels.logs.id,
                    payload: .init(
                        content: DiscordUtils.mention(id: Constants.botDevUserID),
                        embeds: [.init(
                            title: """
                            GHHooks lambda couldn't find a message to edit for a ticket younger than \(firstReportDate)
                            """,
                            color: .red
                        )]
                    )
                ).guardSuccess()
            }

            let response = try await context.discordClient.createMessage(
                channelId: Constants.Channels.issueAndPRs.id,
                payload: .init(embeds: [embed])
            ).decode()
            try await context.messageLookupRepo.saveMessageID(
                messageID: response.id.rawValue,
                repoID: repoID,
                number: number
            )
            return
        }

        try await context.discordClient.updateMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            messageId: messageID,
            payload: .init(embeds: [embed])
        ).guardSuccess()
    }
}
