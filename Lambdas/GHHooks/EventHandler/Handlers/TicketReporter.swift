import DiscordBM
import Shared
import struct Foundation.Date

/// Reports opened/edited issues and PRs.
struct TicketReporter {

    enum Configuration {
        static let userIDDenyList: Set<Int> = [ /* dependabot[bot]: */ 49_699_333]
    }

    private static let ticketQueue = SerialProcessor()

    let context: HandlerContext
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

    func reportCreation() async throws {
        if Configuration.userIDDenyList.contains(authorID) { return }

        try await TicketReporter.ticketQueue.process(queueKey: ticketKey) {
            try await _reportCreation()
        }
    }

    private func _reportCreation() async throws {
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

    func reportEdition() async throws {
        if Configuration.userIDDenyList.contains(authorID) { return }
        try await TicketReporter.ticketQueue.process(queueKey: ticketKey) {
            try await _reportEdition()
        }
    }

    private func _reportEdition() async throws {
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
        default:
            try response.guardSuccess()
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
