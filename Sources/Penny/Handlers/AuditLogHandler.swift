import DiscordBM
import DiscordModels
import Logging
import Models
import NIOCore
import NIOFoundationCompat

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct AuditLogHandler {
    let event: AuditLog.Entry
    let context: HandlerContext
    var discordService: DiscordService {
        context.discordService
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
        case .memberKick:
            guard let userId = event.user_id.map({ UserSnowflake($0) }),
                let targetId = event.target_id.map({ UserSnowflake($0) })
            else {
                logger.error("User id or target id unavailable in memberKick")
                return
            }
            await discordService.sendMessage(
                channelId: Constants.Channels.modLogs.id,
                payload: .init(
                    embeds: [
                        .init(
                            title: "A user was kicked",
                            description: """
                                By: \(DiscordUtils.mention(id: userId))
                                Kicked User: \(DiscordUtils.mention(id: targetId))
                                Reason: \(event.reason ?? "<not-provided>")
                                """,
                            color: .yellow(scheme: .dark)
                        )
                    ]
                )
            )
        case .memberBanAdd:
            guard let userId = event.user_id.map({ UserSnowflake($0) }),
                let targetId = event.target_id.map({ UserSnowflake($0) })
            else {
                logger.error("User id or target id unavailable in memberBanAdd")
                return
            }
            await discordService.sendMessage(
                channelId: Constants.Channels.modLogs.id,
                payload: .init(
                    embeds: [
                        .init(
                            title: "A user was banned",
                            description: """
                                By: \(DiscordUtils.mention(id: userId))
                                Banned User: \(DiscordUtils.mention(id: targetId))
                                Reason: \(event.reason ?? "<not-provided>")
                                """,
                            color: .purple
                        )
                    ]
                )
            )
        case let .messageDelete(channelId, count):
            guard let userId = event.user_id.map({ UserSnowflake($0) }),
                let targetId = event.target_id.map({ UserSnowflake($0) })
            else {
                logger.error("User id or target id unavailable in messageDelete")
                return
            }
            if targetId == Constants.botId {
                logger.warning(
                    "Will not report a messageDelete because target is Penny",
                    metadata: [
                        "userId": .string(userId.rawValue),
                        "targetId": .string(targetId.rawValue),
                    ]
                )
                return
            }
            await discordService.sendMessage(
                channelId: Constants.Channels.modLogs.id,
                payload: .init(
                    embeds: [
                        .init(
                            title: "A message was deleted",
                            description: """
                                By: \(DiscordUtils.mention(id: userId))
                                From: \(DiscordUtils.mention(id: targetId))
                                Count: \(count)
                                In: \(DiscordUtils.mention(id: channelId))
                                """,
                            color: .purple
                        )
                    ]
                )
            )
        case let .messageBulkDelete(count):
            guard let userId = event.user_id.map({ UserSnowflake($0) }),
                let targetId = event.target_id.map({ UserSnowflake($0) })
            else {
                logger.error("User id or target id unavailable in messageBulkDelete")
                return
            }
            if targetId == Constants.botId {
                logger.warning(
                    "Will not report a messageBulkDelete because target is Penny",
                    metadata: [
                        "userId": .string(userId.rawValue),
                        "targetId": .string(targetId.rawValue),
                    ]
                )
                return
            }
            await discordService.sendMessage(
                channelId: Constants.Channels.modLogs.id,
                payload: .init(
                    embeds: [
                        .init(
                            title: "Messages were bulk-deleted",
                            description: """
                                By: \(DiscordUtils.mention(id: userId))
                                From: \(DiscordUtils.mention(id: targetId))
                                Count: \(count)
                                """,
                            color: .purple
                        )
                    ]
                )
            )
        default:
            break
        }
    }
}
