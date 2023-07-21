import DiscordBM

/// Reports opened/edited issues and PRs.
struct Reporter {

    enum Errors: Error, CustomStringConvertible {
        case tooManyMatchingMessagesFound(matchingUrl: String, messages: [DiscordChannel.Message])

        var description: String {
            switch self {
            case let .tooManyMatchingMessagesFound(matchingUrl, messages):
                return "tooManyMatchingMessagesFound(matchingUrl: \(matchingUrl), messages: \(messages))"
            }
        }
    }
    
    let context: HandlerContext

    func reportNew(embed: Embed, repoID: Int, number: Int) async throws {
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

    func reportEdit(embed: Embed, repoID: Int, number: Int) async throws {
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
        } catch {
            context.logger.debug("Couldn't get message ID from Repo, will request", metadata: [
                "error": "\(error)"
            ])
            /// Optimally we should have some kind of database of the issue/pr sent-messages,
            /// so we can lookup the old message id for each issue/pr easily.
            /// But getting messages from Discord and listing them does the trick 95%+ of the times,
            /// and is much simpler.
            let lastMessages = try await context.discordClient.listMessages(
                channelId: Constants.Channels.issueAndPRs.id,
                limit: 100
            ).decode()

            /// Embed url shouldn't be nil based on `createPRReportEmbed()`, but trying to be safe.
            /// The url is, and must remain, the url to the issue/pr, so it can act as an unique
            /// identifier for the message related to an issue/pr.
            let url = try embed.url.requireValue()
            let matchedMessages = lastMessages.filter { $0.embeds.first?.url == url }

            switch matchedMessages.count {
            case 0:
                /// No message found to edit
                context.logger.debug("Couldn't find any messages even with Discord request")
                return
            case 1:
                let message = matchedMessages[0]
                messageID = message.id

                context.logger.debug("Got message ID from Discord", metadata: [
                    "messageID": "\(messageID)"
                ])

                try await context.messageLookupRepo.saveMessageID(
                    messageID: message.id.rawValue,
                    repoID: repoID,
                    number: number
                )
            default:
                throw Errors.tooManyMatchingMessagesFound(matchingUrl: url, messages: matchedMessages)
            }
        }

        try await context.discordClient.updateMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            messageId: messageID,
            payload: .init(embeds: [embed])
        ).guardSuccess()
    }
}
