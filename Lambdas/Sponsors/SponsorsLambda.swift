import AWSLambdaEvents
import AWSLambdaRuntime
import AsyncHTTPClient
import DiscordBM
import HTTPTypes
import LambdasShared
import Models
import NIOHTTP1
import Shared
import SotoCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@main
@dynamicMemberLookup
struct SponsorsHandler {
    struct SharedContext {
        let httpClient: HTTPClient
        let awsClient: AWSClient
        let secretsRetriever: SecretsRetriever
    }

    subscript<T>(dynamicMember keyPath: KeyPath<SharedContext, T>) -> T {
        sharedContext[keyPath: keyPath]
    }

    let sharedContext: SharedContext
    let logger: Logger

    /// We don't do this in the initializer to avoid a possible unnecessary
    /// `secretsRetriever.getSecret()` call which costs $$$.
    var discordClient: any DiscordClient {
        get async throws {
            let botToken = try await self.secretsRetriever.getSecret(arnEnvVarKey: "BOT_TOKEN_ARN")
            return await DefaultDiscordClient(httpClient: self.httpClient, token: botToken)
        }
    }

    enum Constants {
        static let guildID: GuildSnowflake = "431917998102675485"
    }

    static func main() async throws {
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(Lambda.defaultEventLoop),
            configuration: .forPenny
        )
        let awsClient = AWSClient(httpClient: httpClient)
        let secretsRetriever = SecretsRetriever(
            awsClient: awsClient,
            logger: Logger(label: "SponsorsHandler")
        )
        let sharedContext = SharedContext(
            httpClient: httpClient,
            awsClient: awsClient,
            secretsRetriever: secretsRetriever
        )
        try await LambdaRuntime { (event: APIGatewayV2Request, context: LambdaContext) in
            let handler = SponsorsHandler(context: context, sharedContext: sharedContext)
            return await handler.handle(event)
        }.run()
    }

    init(context: LambdaContext, sharedContext: SharedContext) {
        self.sharedContext = sharedContext
        self.logger = context.logger
    }

    func handle(_ event: APIGatewayV2Request) async -> APIGatewayV2Response {
        // Only accept sponsorship events
        self.logger.debug("Headers are: \(event.headers.description)")
        self.logger.debug("Body is: \(event.body ?? "empty")")
        guard event.headers.first(name: "x-github-event") == "sponsorship" else {
            self.logger.debug("Did not get sponsorship event, exiting with code 200")
            return APIGatewayV2Response(statusCode: .ok)
        }
        do {
            self.logger.debug("Received sponsorship event")

            // Try updating the GitHub Readme with the new sponsor
            try await requestReadmeWorkflowTrigger(on: event)

            // Decode GitHub Webhook Response
            self.logger.debug("Decoding GitHub Payload")
            let payload = try event.decode(as: GitHubWebhookPayload.self)

            // Look for the user in the DB
            self.logger.debug("Looking for user in the DB")
            let newSponsorID = payload.sender.id
            let apiBaseURL = try requireEnvVar("API_BASE_URL")
            let userService = ServiceFactory.makeUsersService(
                httpClient: self.httpClient,
                apiBaseURL: apiBaseURL
            )
            guard let user = try await userService.getUser(githubID: "\(newSponsorID)") else {
                self.logger.error("No user found with GitHub ID \(newSponsorID)")
                return APIGatewayV2Response(
                    statusCode: .ok,
                    body: "Error: no user found with GitHub ID \(newSponsorID)"
                )
            }

            // TODO: Create gh user
            let discordID = user.discordID

            // Get role ID based on sponsorship tier
            let role = try SponsorType.for(sponsorshipAmount: payload.sponsorship.tier.monthlyPriceInCents)

            // Do different stuff depending on what happened to the sponsorship
            let actionType = GitHubWebhookPayload.ActionType(rawValue: payload.action)!

            self.logger.debug("Managing Discord roles")

            switch actionType {
            case .created:
                // Add roles to new sponsor
                try await addRole(to: discordID, role: role)
                // If it's a sponsor, we need to add the backer role too
                if role == .sponsor {
                    try await addRole(to: discordID, role: .backer)
                }
                // Send message to new sponsor
                try await sendMessage(to: discordID, role: role)
            case .cancelled:
                try await removeRole(from: discordID, role: .sponsor)
                try await removeRole(from: discordID, role: .backer)
            case .edited:
                break
            case .tierChanged:
                guard let changes = payload.changes else {
                    self.logger.error(
                        "Error: GitHub returned 'tier_changed' event but no 'changes' data in the payload"
                    )
                    return APIGatewayV2Response(
                        statusCode: .ok,
                        body: "Error: GitHub returned 'tier_changed' event but no 'changes' data in the payload"
                    )
                }
                // This means that the user downgraded from a sponsor role to a backer role
                if try SponsorType.for(sponsorshipAmount: changes.tier.from.monthlyPriceInCents) == .sponsor,
                    role == .backer
                {
                    try await removeRole(from: discordID, role: .sponsor)
                }
            case .pendingCancellation:
                break
            case .pendingTierChange:
                break
            }
            self.logger.debug("Done, returning 200")
            return APIGatewayV2Response(statusCode: .ok, body: "All jobs executed correctly")
        } catch {
            self.logger.error(
                "Error when handling sponsorship event",
                metadata: [
                    "error": "\(String(reflecting: error))"
                ]
            )
            return APIGatewayV2Response(
                statusCode: .badRequest,
                body: "Error: \(error)"
            )
        }
    }

    /// Removes a role from the selected Discord user.
    private func removeRole(from discordID: UserSnowflake, role: SponsorType) async throws {
        // Try removing role from user
        do {
            let error = try await discordClient.deleteGuildMemberRole(
                guildId: Constants.guildID,
                userId: discordID,
                roleId: role.roleID
            ).asError()

            switch error {
            case let .some(error):
                switch error {
                case let .jsonError(jsonError)
                where (jsonError.code == .invalidRole) || (jsonError.code == .unknownRole):
                    /// This is fine
                    logger.debug(
                        "User \(discordID) probably didn't have the \(role.rawValue) role in the first place, to be deleted"
                    )
                default:
                    throw error
                }
            case .none:
                logger.info("Successfully removed \(role.rawValue) role from user \(discordID)")
            }
        } catch {
            logger.error("Failed to remove \(role.rawValue) role from user \(discordID) with error: \(error)")
            throw Errors.addMemberRoleError(
                message: "Failed to remove \(role.rawValue) role from user \(discordID) with error: \(error)"
            )
        }
    }

    /// Adds a new Discord role to the selected user, depending on the sponsorship tier they selected (**sponsor**, **backer**).
    private func addRole(to discordID: UserSnowflake, role: SponsorType) async throws {
        do {
            // Try adding role to new sponsor
            try await discordClient.addGuildMemberRole(
                guildId: Constants.guildID,
                userId: discordID,
                roleId: role.roleID
            ).guardSuccess()
            logger.info("Successfully added \(role) role to user \(discordID).")
        } catch {
            logger.error("Failed to add \(role) role to member \(discordID) with error: \(error)")
            throw Errors.addMemberRoleError(
                message: "Failed to add \(role) role to member \(discordID) with error: \(error)"
            )
        }
    }

    /// Sends a message welcoming the user in the new channel and giving them a coin.
    private func sendMessage(to discordID: UserSnowflake, role: SponsorType) async throws {
        do {
            // Try sending message to new sponsor
            try await discordClient.createMessage(
                // Always send message to backer channel only
                channelId: SponsorType.backer.channelID,
                payload: .init(embeds: [
                    .init(
                        description:
                            "Welcome \(DiscordUtils.mention(id: discordID)), our new \(DiscordUtils.mention(id: role.roleID))",
                        color: role.discordColor
                    )
                ])
            ).guardSuccess()
            logger.info("Successfully sent message to user \(discordID).")
        } catch {
            logger.error("Failed to send message with error: \(error)")
            throw Errors.sendWelcomeMessageError(
                message: "Failed to send message with error: \(error)"
            )
        }
    }

    private func getWorkflowToken() async throws -> String {
        try await self.secretsRetriever.getSecret(arnEnvVarKey: "GH_WORKFLOW_TOKEN_ARN")
    }

    /// Sends a request to GitHub to trigger the workflow that is going to update the repository readme file with the new sponsor.
    private func requestReadmeWorkflowTrigger(on event: APIGatewayV2Request) async throws {
        // Create request to trigger workflow
        let url = "https://api.github.com/repos/vapor/vapor/actions/workflows/sponsors.yml/dispatches"
        var triggerActionRequest = HTTPClientRequest(url: url)
        triggerActionRequest.method = .POST

        let workflowToken = try await getWorkflowToken()

        triggerActionRequest.headers.add(contentsOf: [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(workflowToken)",
            "User-Agent": "Penny/1.0.0 (https://github.com/vapor/penny-bot)",
        ])

        triggerActionRequest.body = .bytes(ByteBuffer(string: #"{"ref":"main"}"#))

        // Send request to trigger workflow and read response
        let githubResponse = try await self.httpClient.execute(triggerActionRequest, timeout: .seconds(10))

        guard 200..<300 ~= githubResponse.status.code else {
            let body = try await githubResponse.body.collect(upTo: 1024 * 1024)
            logger.error(
                "GitHub did not run workflow with error code: \(githubResponse.status.code) and body: \(String(buffer: body))"
            )
            throw Errors.runWorkflowError(
                message: "GitHub did not run workflow with error code: \(githubResponse.status.code)"
            )
        }
        logger.info("Successfully ran GitHub workflow with response code: \(githubResponse.status.code)")
    }
}

extension ByteBuffer? {
    var string: String {
        guard let self = self else {
            return "empty"
        }
        return String(buffer: self)
    }
}
