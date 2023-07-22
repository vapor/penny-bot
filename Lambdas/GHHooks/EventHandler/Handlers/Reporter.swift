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
        } catch let error as DynamoMessageRepo.Errors where error == .notFound {
            context.logger.warning("Didn't find a message id from the lookup repo", metadata: [
                "repoID": .stringConvertible(repoID),
                "number": .stringConvertible(number),
            ])
            return
        }

        try await context.discordClient.updateMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            messageId: messageID,
            payload: .init(embeds: [embed])
        ).guardSuccess()
    }
}
