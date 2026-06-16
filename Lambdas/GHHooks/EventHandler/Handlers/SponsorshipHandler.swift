import AsyncHTTPClient
import DiscordBM
import GitHubAPI
import LambdasShared
import Logging
import Models
import NIOCore
import NIOHTTP1
import Shared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Handles GitHub Sponsors `sponsorship` webhook events:
/// 1. Triggers the `vapor/vapor` workflow that regenerates the sponsors README.
/// 2. Adds/removes the relevant Discord roles and welcomes new sponsors.
struct SponsorshipHandler: Sendable {
    let context: HandlerContext

    var event: GHEvent {
        self.context.event
    }

    var logger: Logger {
        self.context.logger
    }

    func handle() async throws {
        try await self.requestReadmeWorkflowTrigger()

        guard let action = event.action.flatMap(GHEvent.Sponsorship.Action.init(rawValue:)) else {
            logger.error("Unknown or missing sponsorship action", metadata: ["action": "\(event.action ?? "<null>")"])
            return
        }

        let sponsorship = try event.sponsorship.requireValue()
        let role = try SponsorType.for(sponsorshipAmount: sponsorship.tier.monthly_price_in_cents)
        let sender = try event.sender.requireValue()

        guard let user = try await self.context.usersService.getUser(githubID: "\(sender.id)") else {
            logger.error("No user found with GitHub ID", metadata: ["githubID": "\(sender.id)"])
            return
        }
        let discordID = user.discordID

        logger.debug("Managing Discord roles", metadata: ["action": "\(action)"])

        switch action {
        case .created:
            try await self.addRole(to: discordID, role: role)
            if role == .sponsor {
                try await self.addRole(to: discordID, role: .backer)
            }
            try await self.sendWelcomeMessage(to: discordID, role: role)
        case .cancelled:
            try await self.removeRole(from: discordID, role: .sponsor)
            try await self.removeRole(from: discordID, role: .backer)
        case .tierChanged:
            let from = try event.changes.requireValue().tier.requireValue().from
            /// If they downgraded from a sponsor to a backer, remove the sponsor role.
            if try SponsorType.for(sponsorshipAmount: from.monthly_price_in_cents) == .sponsor,
                role == .backer
            {
                try await self.removeRole(from: discordID, role: .sponsor)
            }
        case .edited, .pendingCancellation, .pendingTierChange:
            break
        }
    }

    /// Triggers the `vapor/vapor` workflow that updates the README with the new sponsor.
    private func requestReadmeWorkflowTrigger() async throws {
        let secretsRetriever = try self.context.secretsRetriever.requireValue()
        let workflowToken = try await secretsRetriever.getSecret(arnEnvVarKey: "GH_WORKFLOW_TOKEN_ARN")

        var request = HTTPClientRequest(
            url: "https://api.github.com/repos/vapor/vapor/actions/workflows/sponsors.yml/dispatches"
        )
        request.method = .POST
        request.headers.add(contentsOf: [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(workflowToken)",
            "User-Agent": "Penny/1.0.0 (https://github.com/vapor/penny-bot)",
        ])
        request.body = .bytes(ByteBuffer(string: #"{"ref":"main"}"#))

        let response = try await self.context.httpClient.execute(request, timeout: .seconds(10))
        guard 200..<300 ~= response.status.code else {
            let body = try await response.body.collect(upTo: 1024 * 1024)
            logger.error(
                "GitHub did not run the sponsors workflow",
                metadata: [
                    "status": "\(response.status.code)",
                    "body": "\(String(buffer: body))",
                ]
            )
            throw SponsorshipError.runWorkflowFailed(status: response.status.code)
        }
        logger.info("Successfully triggered the sponsors README workflow")
    }

    private func addRole(to discordID: UserSnowflake, role: SponsorType) async throws {
        do {
            try await self.context.discordClient.addGuildMemberRole(
                guildId: Constants.guildID,
                userId: discordID,
                roleId: role.roleID
            ).guardSuccess()
            logger.info("Added role to user", metadata: ["role": "\(role)", "user": "\(discordID)"])
        } catch {
            logger.error(
                "Failed to add role to user",
                metadata: ["role": "\(role)", "user": "\(discordID)", "error": "\(error)"]
            )
            throw error
        }
    }

    private func removeRole(from discordID: UserSnowflake, role: SponsorType) async throws {
        let error = try await self.context.discordClient.deleteGuildMemberRole(
            guildId: Constants.guildID,
            userId: discordID,
            roleId: role.roleID
        ).asError()

        switch error {
        case let .some(.jsonError(jsonError))
        where (jsonError.code == .invalidRole) || (jsonError.code == .unknownRole):
            logger.debug(
                "User probably didn't have the role to be removed",
                metadata: ["role": "\(role)", "user": "\(discordID)"]
            )
        case let .some(error):
            throw error
        case .none:
            logger.info("Removed role from user", metadata: ["role": "\(role)", "user": "\(discordID)"])
        }
    }

    private func sendWelcomeMessage(to discordID: UserSnowflake, role: SponsorType) async throws {
        try await self.context.discordClient.createMessage(
            /// Always announce in the backer channel.
            channelId: SponsorType.backer.channelID,
            payload: .init(embeds: [
                .init(
                    description:
                        "Welcome \(DiscordUtils.mention(id: discordID)), our new \(DiscordUtils.mention(id: role.roleID))",
                    color: role.discordColor
                )
            ])
        ).guardSuccess()
        logger.info("Sent welcome message to user", metadata: ["user": "\(discordID)"])
    }
}

enum SponsorshipError: Error, CustomStringConvertible {
    case runWorkflowFailed(status: UInt)
    case noSponsorType(amount: Int)

    var description: String {
        switch self {
        case let .runWorkflowFailed(status):
            return "runWorkflowFailed(status: \(status))"
        case let .noSponsorType(amount):
            return "noSponsorType(amount: \(amount))"
        }
    }
}

enum SponsorType: String, Sendable {
    case sponsor
    case backer

    var roleID: RoleSnowflake {
        switch self {
        case .sponsor: "444167329748746262"
        case .backer: "431921695524126722"
        }
    }

    var channelID: ChannelSnowflake {
        "633345683012976640"
    }

    var discordColor: DiscordColor {
        switch self {
        case .sponsor: .yellow
        case .backer: .green
        }
    }

    static func `for`(sponsorshipAmount: Int) throws -> SponsorType {
        switch sponsorshipAmount {
        case 500...9900: .backer
        case 10000...: .sponsor
        default: throw SponsorshipError.noSponsorType(amount: sponsorshipAmount)
        }
    }
}

extension GHEvent.Sponsorship {
    /// The `action` values GitHub sends with `sponsorship` events.
    /// https://docs.github.com/en/webhooks/webhook-events-and-payloads#sponsorship
    enum Action: String, Sendable {
        case created
        case cancelled
        case edited
        case tierChanged = "tier_changed"
        case pendingCancellation = "pending_cancellation"
        case pendingTierChange = "pending_tier_change"
    }
}
