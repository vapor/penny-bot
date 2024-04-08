import DiscordBM
import Foundation
import Logging
import NIOCore
import NIOFoundationCompat
import Models

struct AuditLogHandler {
    let event: AuditLog.Entry
    let context: HandlerContext
    var discordService: DiscordService {
        context.services.discordService
    }
    var logger = Logger(label: "AuditLogHandler")

    init(
        event: AuditLog.Entry,
        context: HandlerContext
    ) {
        self.event = event
        self.context = context
        self.logger[metadataKey: "event"] = "\(event)"
    }

    func handle() async throws {
        switch event.action {
        case .memberBanAdd:
            guard let userId = event.user_id.map({ UserSnowflake($0) }),
                  let targetId = event.target_id.map({ UserSnowflake($0) }) else {
                logger.error("User id or target id unavailable in memberBanAdd")
                return
            }
            await discordService.sendMessage(
                channelId: Constants.Channels.moderators.id,
                payload: .init(
                    embeds: [.init(
                        title: "A user was banned",
                        description: """
                        By: \(DiscordUtils.mention(id: userId))
                        Banned User: \(DiscordUtils.mention(id: targetId))
                        Reason: \(event.reason ?? "<not-provided>")
                        """,
                        color: .purple
                    )]
                )
            )
        case let .messageDelete(channelId, count):
            guard let userId = event.user_id.map({ UserSnowflake($0) }),
                  let targetId = event.target_id.map({ UserSnowflake($0) }) else {
                logger.error("User id or target id unavailable in messageDelete")
                return
            }
            await discordService.sendMessage(
                channelId: Constants.Channels.moderators.id,
                payload: .init(
                    embeds: [.init(
                        title: "A message was deleted",
                        description: """
                        By: \(DiscordUtils.mention(id: userId))
                        From: \(DiscordUtils.mention(id: targetId))
                        Count: \(count)
                        In: \(DiscordUtils.mention(id: channelId))
                        """,
                        color: .purple
                    )]
                )
            )
        case let .messageBulkDelete(count):
            guard let userId = event.user_id.map({ UserSnowflake($0) }),
                  let targetId = event.target_id.map({ UserSnowflake($0) }) else {
                logger.error("User id or target id unavailable in messageBulkDelete")
                return
            }
            await discordService.sendMessage(
                channelId: Constants.Channels.moderators.id,
                payload: .init(
                    embeds: [.init(
                        title: "Messages were bulk-deleted",
                        description: """
                        By: \(DiscordUtils.mention(id: userId))
                        From: \(DiscordUtils.mention(id: targetId))
                        Count: \(count)
                        """,
                        color: .purple
                    )]
                )
            )
        default:
            break
        }
    }
}
