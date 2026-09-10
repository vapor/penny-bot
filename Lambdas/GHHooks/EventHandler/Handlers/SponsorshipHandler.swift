import DiscordBM
import GitHubAPI
import Logging
import Models
import Shared

/// Handles GitHub Sponsors `sponsorship` webhook events by adding/removing the relevant
/// Discord roles and welcoming new sponsors.
struct SponsorshipHandler: Sendable {
    let context: HandlerContext
    let action: Sponsorship.Action
    let sponsorship: Sponsorship
    let tier: SponsorType
    let sponsor: Sponsorship.SponsorPayload
    let logger: Logger

    var event: GHEvent {
        self.context.event
    }

    init(context: HandlerContext) throws {
        self.context = context
        self.action = try context.event.action
            .flatMap(Sponsorship.Action.init(rawValue:))
            .requireValue()
        self.sponsorship = try context.event.sponsorship.requireValue()
        self.tier = try SponsorType.for(sponsorshipAmount: self.sponsorship.tier.monthlyPriceInCents)
        self.sponsor = try self.sponsorship.sponsor.requireValue()

        var logger = context.logger
        logger[metadataKey: "action"] = "\(self.action)"
        logger[metadataKey: "tier"] = "\(self.tier)"
        logger[metadataKey: "githubID"] = "\(self.sponsor.id)"
        self.logger = logger
    }

    func handle() async throws {
        guard let user = try await self.context.usersService.getUser(githubID: "\(self.sponsor.id)") else {
            logger.error("No user found with GitHub ID")
            return
        }
        let discordID = user.discordID

        logger.debug("Managing Discord roles")

        guard let currentRoles = try await self.getCurrentRoles(of: discordID) else {
            logger.error("User is not a member of the Discord server", metadata: ["user": "\(discordID)"])
            return
        }

        switch self.action {
        case .created:
            try await self.addRole(to: discordID, role: self.tier, currentRoles: currentRoles)
            if self.tier == .sponsor {
                try await self.addRole(to: discordID, role: .backer, currentRoles: currentRoles)
            }
            try await self.sendWelcomeMessage(to: discordID, role: self.tier)
        case .cancelled:
            try await withThrowingAccumulatingVoidTaskGroup(tasks: [
                { try await self.removeRole(from: discordID, role: .sponsor, currentRoles: currentRoles) },
                { try await self.removeRole(from: discordID, role: .backer, currentRoles: currentRoles) },
            ])
        case .tier_changed:
            let from = try event.changes.requireValue().tier.requireValue().from
            /// If they downgraded from a sponsor to a backer, remove the sponsor role.
            if try SponsorType.for(sponsorshipAmount: from.monthlyPriceInCents) == .sponsor,
                self.tier == .backer
            {
                try await self.removeRole(from: discordID, role: .sponsor, currentRoles: currentRoles)
            }
        case .edited, .pending_cancellation, .pending_tier_change:
            break
        }
    }

    /// Returns `nil` if the user is not a member of the Discord server.
    private func getCurrentRoles(of discordID: UserSnowflake) async throws -> [RoleSnowflake]? {
        let response = try await self.context.discordClient.getGuildMember(
            guildId: Constants.guildID,
            userId: discordID
        )

        switch response.asError() {
        case let .some(.jsonError(jsonError)) where jsonError.code == .unknownMember:
            return nil
        case let .some(error):
            throw error
        case .none:
            return try response.decode().roles
        }
    }

    private func addRole(
        to discordID: UserSnowflake,
        role: SponsorType,
        currentRoles: [RoleSnowflake]
    ) async throws {
        guard !currentRoles.contains(role.roleID) else {
            logger.debug("User already has the role", metadata: ["role": "\(role)", "user": "\(discordID)"])
            return
        }

        let error = try await self.context.discordClient.addGuildMemberRole(
            guildId: Constants.guildID,
            userId: discordID,
            roleId: role.roleID
        ).asError()

        switch error {
        case let .some(.jsonError(jsonError))
        where (jsonError.code == .missingAccess) || (jsonError.code == .missingPermissions):
            logger.error(
                "Penny is missing the 'Manage Roles' permission in the Discord server",
                metadata: ["role": "\(role)", "user": "\(discordID)", "error": "\(jsonError)"]
            )
            throw DiscordHTTPErrorResponse.jsonError(jsonError)
        case let .some(error):
            logger.error(
                "Failed to add role to user",
                metadata: ["role": "\(role)", "user": "\(discordID)", "error": "\(error)"]
            )
            throw error
        case .none:
            logger.info("Added role to user", metadata: ["role": "\(role)", "user": "\(discordID)"])
        }
    }

    private func removeRole(
        from discordID: UserSnowflake,
        role: SponsorType,
        currentRoles: [RoleSnowflake]
    ) async throws {
        guard currentRoles.contains(role.roleID) else {
            logger.debug(
                "User doesn't have the role to be removed",
                metadata: ["role": "\(role)", "user": "\(discordID)"]
            )
            return
        }

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
        case let .some(.jsonError(jsonError))
        where (jsonError.code == .missingAccess) || (jsonError.code == .missingPermissions):
            logger.error(
                "Penny is missing the 'Manage Roles' permission in the Discord server",
                metadata: ["role": "\(role)", "user": "\(discordID)", "error": "\(jsonError)"]
            )
            throw DiscordHTTPErrorResponse.jsonError(jsonError)
        case let .some(error):
            logger.error(
                "Failed to remove role from user",
                metadata: ["role": "\(role)", "user": "\(discordID)", "error": "\(error)"]
            )
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
    case noSponsorType(amount: Int)

    var description: String {
        switch self {
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
        case .sponsor: Constants.Roles.sponsor.id
        case .backer: Constants.Roles.backer.id
        }
    }

    var channelID: ChannelSnowflake {
        Constants.Channels.backers.id
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
