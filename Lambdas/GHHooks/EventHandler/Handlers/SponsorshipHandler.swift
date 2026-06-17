import DiscordBM
import GitHubAPI
import Logging
import Models
import Shared

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
        try await self.context.requester.triggerSponsorsWorkflow()

        guard let action = event.action.flatMap(Sponsorship.Action.init(rawValue:)) else {
            logger.error("Unknown or missing sponsorship action", metadata: ["action": "\(event.action ?? "<null>")"])
            return
        }

        let sponsorship = try event.sponsorship.requireValue()
        let role = try SponsorType.for(sponsorshipAmount: sponsorship.tier.monthlyPriceInCents)
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
        case .tier_changed:
            let from = try event.changes.requireValue().tier.requireValue().from
            /// If they downgraded from a sponsor to a backer, remove the sponsor role.
            if try SponsorType.for(sponsorshipAmount: from.monthlyPriceInCents) == .sponsor,
                role == .backer
            {
                try await self.removeRole(from: discordID, role: .sponsor)
            }
        case .edited, .pending_cancellation, .pending_tier_change:
            break
        }
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
