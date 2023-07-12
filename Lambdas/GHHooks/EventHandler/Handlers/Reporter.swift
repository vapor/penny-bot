import DiscordBM

/// Reports opened/edited issues and PRs.
struct Reporter {

    enum Errors: Error, CustomStringConvertible {
        case tooManyMatchingMessagesFound(matchingTitle: String, messages: [DiscordChannel.Message])

        var description: String {
            switch self {
            case let .tooManyMatchingMessagesFound(matchingTitle, messages):
                return "tooManyMatchingMessagesFound(matchingTitle: \(matchingTitle), messages: \(messages))"
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
        let lastMessages = try await context.discordClient.listMessages(
            channelId: Constants.Channels.issueAndPRs.id,
            limit: 100
        ).decode()

        /// Embed title shouldn't be nil based on `createPRReportEmbed()`, but trying to be safe.
        let embedTitle = try embed.title.requireValue()
        let matchedMessages = lastMessages.filter { $0.embeds.first?.title == embedTitle }

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
            throw Errors.tooManyMatchingMessagesFound(
                matchingTitle: embedTitle,
                messages: matchedMessages
            )
        }
    }
}
