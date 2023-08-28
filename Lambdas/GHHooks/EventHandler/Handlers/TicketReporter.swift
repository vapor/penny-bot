import DiscordBM
import struct Foundation.Date

/// Reports opened/edited issues and PRs.
struct TicketReporter {
    let context: HandlerContext
    let embed: Embed
    let repoID: Int
    let number: Int

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
        } catch let error as DynamoMessageRepo.Errors where error == .unavailable {
            context.logger.debug("Message is unavailable to edit", metadata: [
                "repoID": .stringConvertible(repoID),
                "number": .stringConvertible(number),
            ])
            return
        } catch let error as DynamoMessageRepo.Errors where error == .notFound {
            context.logger.debug(
                "Didn't find a message id from the lookup repo, will send a new message",
                metadata: [
                    "repoID": .stringConvertible(repoID),
                    "number": .stringConvertible(number),
                ]
            )

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

        let response = try await context.discordClient.updateMessage(
            channelId: Constants.Channels.issueAndPRs.id,
            messageId: messageID,
            payload: .init(embeds: [embed])
        )

        switch response.asError() {
        case let .jsonError(jsonError) where jsonError.code == .unknownMessage:
            context.logger.debug(
                "Discord says message id is unknown. Will mark as unavailable in DB.",
                metadata: [
                    "messageID": .stringConvertible(messageID),
                    "repoID": .stringConvertible(repoID),
                    "number": .stringConvertible(number),
                ]
            )
            try await context.messageLookupRepo.markAsUnavailable(
                repoID: repoID,
                number: number
            )
            return
        default: break
        }

        try response.guardSuccess()
    }
}
