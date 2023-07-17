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

    func reportNew(embed: Embed) async throws {
        try await context.discordClient.createMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            payload: .init(embeds: [embed])
        ).guardSuccess()
    }

    func reportEdit(embed: Embed) async throws {
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
            return
        case 1:
            let message = matchedMessages[0]
            if let existingEmbed = message.embeds.first,
               existingEmbed == embed {
                context.logger.debug("Embeds are equal. Will not edit message", metadata: [
                    "existing": "\(existingEmbed)",
                    "new": "\(embed)"
                ])
                return
            }
            try await context.discordClient.updateMessage(
                channelId: Constants.Channels.issueAndPRs.id,
                messageId: message.id,
                payload: .init(embeds: [embed])
            ).guardSuccess()
        default:
            throw Errors.tooManyMatchingMessagesFound(matchingUrl: url, messages: matchedMessages)
        }
    }
}
