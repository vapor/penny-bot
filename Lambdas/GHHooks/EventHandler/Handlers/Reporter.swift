import DiscordBM

/// Reports opened/edited issues and PRs.
struct Reporter {

    enum Errors: Error, CustomStringConvertible {
        case tooManyMatchingMessagesFound(
            matchingTitleProperties: [String],
            messages: [DiscordChannel.Message]
        )

        var description: String {
            switch self {
            case let .tooManyMatchingMessagesFound(matchingTitleProperties, messages):
                return "tooManyMatchingMessagesFound(matchingTitleProperties: \(matchingTitleProperties), messages: \(messages))"
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

    func reportEdit(embed: Embed, searchableTitleProperties: [String]) async throws {
        /// Optimally we should have some kind of database of the issue/pr sent-messages,
        /// so we can lookup the old message id for each issue/pr easily.
        /// But getting messages from Discord and listing them does the trick 95%+ of the times,
        /// and is much simpler.
        let lastMessages = try await context.discordClient.listMessages(
            channelId: Constants.Channels.issueAndPRs.id,
            limit: 100
        ).decode()

        /// Embed title shouldn't be nil based on `createPRReportEmbed()`, but trying to be safe.
        let matchedMessages = lastMessages.filter { message in
            guard let title = message.embeds.first?.title else {
                return false
            }
            return searchableTitleProperties.allSatisfy({ title.contains($0) })
        }

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
                matchingTitleProperties: searchableTitleProperties,
                messages: matchedMessages
            )
        }
    }
}
