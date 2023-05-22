import AsyncHTTPClient
import AWSLambdaRuntime
import AWSLambdaEvents
import DiscordBM
import Foundation
import NIOHTTP1
import PennyExtensions
import PennyServices
import SotoCore
import SotoSecretsManager

enum GithubRequestError: Error, LocalizedError {
    case runWorkflowError(message: String)
    var errorDescription: String? {
        switch self {
        case let .runWorkflowError(message):
            return NSLocalizedString(message, comment: "")
        }
    }
}

enum DiscordRequestError: Error, LocalizedError {
    case addMemberRoleError(message: String)
    case sendWelcomeMessageError(message: String)
    var errorDescription: String? {
        switch self {
        case let .addMemberRoleError(message):
            return NSLocalizedString(message, comment: "")
        case let .sendWelcomeMessageError(message):
            return NSLocalizedString(message, comment: "")
        }
    }
}

struct ClientFailedShutdownError: Error {
    let message = "Failed to shutdown HTTP Client"
}

@main
struct AddSponsorHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let httpClient: HTTPClient
    let awsClient: AWSClient
    let secretsManager: SecretsManager
    
    struct Constants {
        static let guildID: GuildSnowflake = "431917998102675485"
    }

    init(context: LambdaInitializationContext) async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        self.httpClient = httpClient
        let awsClient = AWSClient(httpClientProvider: .shared(httpClient))
        self.awsClient = awsClient
        context.terminator.register(name: "Client shutdown") { eventLoop in
            do {
                try awsClient.syncShutdown()
                try httpClient.syncShutdown()
                return eventLoop.makeSucceededVoidFuture()
            } catch {
                return eventLoop.makeFailedFuture(ClientFailedShutdownError())
            }
        }
        self.secretsManager = SecretsManager(client: awsClient)
    }
    
    private func setupDiscordClient(context: LambdaContext) async throws -> any DiscordClient {
        // Get the ARN to retrieve the appID stored inside of the secrets manager
        guard let appIDArn = ProcessInfo.processInfo.environment["APP_ID_ARN"] else {
            fatalError("Couldn't retrieve APP_ID_ARN env var")
        }
        
        // Request the appID secret from the secrets manager
        context.logger.debug("Retrieving secrets...")
        // FIXME By Mahdi: APP ID is quite public. The aws console values are also not right.
        // 1- In aws console, swap these 2 env var's values.
        // 2- swap their places in this code below too.
        let appIDSecretRequest = SecretsManager.GetSecretValueRequest(secretId: appIDArn)
        let appIDResponse = try await secretsManager.getSecretValue(appIDSecretRequest)
        guard let appID = appIDResponse.secretString else {
            fatalError("Couldn't retrieve Bot App ID Secret")
        }
        guard let token = ProcessInfo.processInfo.environment["BOT_TOKEN"] else {
            fatalError("Missing 'BOT_TOKEN' env var")
        }
        context.logger.debug("Secrets retrieved")
        return await DefaultDiscordClient(
            httpClient: httpClient,
            token: token,
            appId: Snowflake(appID)
        )
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        // Only accept sponsorship events
        context.logger.debug("Headers are: \(event.headers.description)")
        context.logger.debug("Body is: \(event.body ?? "empty")")
        guard event.headers["X-Github-Event"] == "sponsorship"
                || event.headers["x-github-event"] == "sponsorship"
        else {
            context.logger.debug("Did not get sponsorship event, exiting with code 200")
            return APIGatewayV2Response(statusCode: .ok)
        }
        do {
            context.logger.debug("Received sponsorship event")
            let discordClient = try await setupDiscordClient(context: context)
            
            // Try updating the GitHub Readme with the new sponsor
            try await requestReadmeWorkflowTrigger(on: event, context: context)
            
            // Decode GitHub Webhook Response
            context.logger.debug("Decoding GitHub Payload")
            let payload: GithubWebhookPayload = try event.bodyObject()
            
            // Look for the user in the DB
            context.logger.debug("Looking for user in the DB")
            let newSponsorID = payload.sender.id
            let userService = UserService(awsClient, context.logger)
            let user = try await userService.getUserWith(githubID: String(newSponsorID))
            guard let user = user else {
                context.logger.error("No user found with Github ID \(newSponsorID)")
                return APIGatewayV2Response(
                    statusCode: .ok,
                    body: "Error: no user found with GitHub ID \(newSponsorID)"
                )
            }
            
            // TODO: Create gh user
            guard let userDiscordID = user.discordID else {
                context.logger.error("User \(newSponsorID) did not link a Discord account")
                return APIGatewayV2Response(
                    statusCode: .ok,
                    body: "Error: user \(newSponsorID) did not link a Discord account"
                )
            }
            
            // Get role ID based on sponsorship tier
            let role = try SponsorType.for(sponsorshipAmount: payload.sponsorship.tier.monthlyPriceInCents)
            
            // Do different stuff depending on what happened to the sponsorship
            let actionType = GithubWebhookPayload.ActionType(rawValue: payload.action)!
            
            context.logger.debug("Managing Discord roles")
            
            switch actionType {
            case .created:
                // Add roles to new sponsor
                try await addRole(to: userDiscordID, from: payload, discordClient: discordClient, role: role, context: context)
                // If it's a sponsor, we need to add the backer role too
                if role == .sponsor {
                    try await addRole(to: userDiscordID, from: payload, discordClient: discordClient, role: .backer, context: context)
                }
                // Send message to new sponsor
                try await sendMessage(to: userDiscordID, from: payload, discordClient: discordClient, role: role, context: context)
            case .cancelled:
                try await removeRole(from: userDiscordID, using: payload, discordClient: discordClient, role: .sponsor, context: context)
                try await removeRole(from: userDiscordID, using: payload, discordClient: discordClient, role: .backer, context: context)
            case .edited:
                break
            case .tierChanged:
                guard let changes = payload.changes else {
                    context.logger.error("Error: Github returned 'tier_changed' event but no 'changes' data in the payload")
                    return APIGatewayV2Response(
                        statusCode: .ok,
                        body: "Error: Github returned 'tier_changed' event but no 'changes' data in the payload"
                    )
                }
                // This means that the user downgraded from a sponsor role to a backer role
                if try SponsorType.for(sponsorshipAmount: changes.tier.from.monthlyPriceInCents) == .sponsor,
                   role == .backer {
                    try await removeRole(from: userDiscordID, using: payload, discordClient: discordClient, role: .sponsor, context: context)
                }
            case .pendingCancellation:
                break
            case .pendingTierChange:
                break
            }
            context.logger.debug("Done, returning 200")
            return APIGatewayV2Response(statusCode: .ok, body: "All jobs executed correctly")
        } catch let error {
            context.logger.error("Error: \(error.localizedDescription)")
            return APIGatewayV2Response(
                statusCode: .badRequest,
                body: "Error: \(error.localizedDescription)"
            )
        }
    }
    
    /**
     Removes a role from the selected Discord user.
     */
    private func removeRole(
        from userDiscordID: String,
        using githubPayload: GithubWebhookPayload,
        discordClient: any DiscordClient,
        role: SponsorType,
        context: LambdaContext
    ) async throws {
        let userDiscordID = userDiscordID.makePlainID()
        // Try removing role from user
        let removeRoleResponse = try await discordClient.deleteGuildMemberRole(
            guildId: Constants.guildID,
            userId: Snowflake(userDiscordID),
            // FIXME By Mahdi: change to `role.roleID`
            roleId: SponsorType.backer.roleID
        )
        
        // Throw if adding new role response is invalid
        guard 200...299 ~= removeRoleResponse.status.code else {
            context.logger.error("Failed to remove \(role.rawValue) role from user \(userDiscordID) with error: \(removeRoleResponse.status.description) and body: \(removeRoleResponse.body.string)")
            throw DiscordRequestError.addMemberRoleError(
                message: "Failed to remove \(role.rawValue) role from user \(userDiscordID) with error: \(removeRoleResponse.status.description)"
            )
        }
        context.logger.info("Successfully removed \(role.rawValue) role from user \(userDiscordID) with response code: \(removeRoleResponse.status.code)")
    }
    
    /**
     Adds a new Discord role to the selected user, depending on the sponsorship tier they selected (**sponsor**, **backer**).
     */
    private func addRole(
        to userDiscordID: String,
        from githubPayload: GithubWebhookPayload,
        discordClient: any DiscordClient,
        role: SponsorType,
        context: LambdaContext
    ) async throws {
        // Try adding role to new sponsor
        let addRoleResponse = try await discordClient.addGuildMemberRole(
            guildId: Constants.guildID,
            userId: Snowflake(userDiscordID),
            roleId: role.roleID
        )

        // Throw if adding new role response is invalid
        guard 200...299 ~= addRoleResponse.status.code else {
            context.logger.error("Failed to add \(role.rawValue) role to member \(userDiscordID) with error: \(addRoleResponse.status.description) and body: \(addRoleResponse.body.string)")
            throw DiscordRequestError.addMemberRoleError(
                message: "Failed to add \(role.rawValue) role to member \(userDiscordID) with error: \(addRoleResponse.status.description)"
            )
        }
        context.logger.info("Successfully added \(role.rawValue) role to user \(userDiscordID) with response code: \(addRoleResponse.status.code)")
    }

    /**
     Sends a message welcoming the user in the new channel and giving them a coin.
     */
    private func sendMessage(
        to userDiscordID: String,
        from githubPayload: GithubWebhookPayload,
        discordClient: any DiscordClient,
        role: SponsorType,
        context: LambdaContext
    ) async throws {
        // Try sending message to new sponsor
        let createMessageResponse = try await discordClient.createMessage(
            // Always send message to backer channel only
            channelId: SponsorType.backer.channelID,
            payload: .init(
                embeds: [.init(
                    description: "Welcome <@\(userDiscordID)>, our new \(role.rawValue) ++"
                )]
            )
        )
        // Throw if response is invalid
        guard 200...299 ~= createMessageResponse.httpResponse.status.code else {
            context.logger.error("Failed to send message with error: \(createMessageResponse.httpResponse.status.code) and body: \(createMessageResponse.httpResponse.body.string)")
            throw DiscordRequestError.sendWelcomeMessageError(
                message: "Failed to send message with error: \(createMessageResponse.httpResponse.status.code)"
            )
        }
        context.logger.info("Successfully sent message to user \(userDiscordID) with response code: \(createMessageResponse.httpResponse.status.code)")
    }
    
    /**
     Sends a request to GitHub to trigger the workflow that is going to update the repository readme file with the new sponsor.
        - returns The response status of the request
     */
    private func requestReadmeWorkflowTrigger(
        on event: APIGatewayV2Request,
        context: LambdaContext
    ) async throws {
        // Create request to trigger workflow
        let url = "https://api.github.com/repos/vapor/vapor/actions/workflows/sponsors.yml/dispatches"
        var triggerActionRequest = HTTPClientRequest(url: url)
        triggerActionRequest.method = .POST
        
        // Retrieve GH token from AWS Secrets Manager
        guard let workflowTokenArn = ProcessInfo.processInfo.environment["GH_WORKFLOW_TOKEN_ARN"] else {
            fatalError("Couldn't retrieve GH_WORKFLOW_TOKEN_ARN env var")
        }
        let workflowTokenRequest = SecretsManager.GetSecretValueRequest(secretId: workflowTokenArn)
        let workflowToken = try await secretsManager.getSecretValue(workflowTokenRequest)
        guard let workflowTokenString = workflowToken.secretString else {
            fatalError("Couldn't retrieve Github token from AWS Secrets Manager")
        }
        
        // The token is going to have to be in the SecretsManager in AWS
        triggerActionRequest.headers.add(contentsOf: [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(workflowTokenString)",
            "User-Agent": "penny-bot"
        ])
        
        triggerActionRequest.body = .bytes(ByteBuffer(string: "{\"ref\": \"main\"}"))
        
        // Send request to trigger workflow and read response
        let githubResponse = try await httpClient.execute(triggerActionRequest, timeout: .seconds(10))
        
        guard 200...299 ~= githubResponse.status.code else {
            let body = try await githubResponse.body.collect(upTo: 1024 * 1024)
            context.logger.error("GitHub did not run workflow with error code: \(githubResponse.status.code) and body: \(String(buffer: body))")
            throw GithubRequestError.runWorkflowError(
                message: "GitHub did not run workflow with error code: \(githubResponse.status.code)"
            )
        }
        context.logger.info("Successfully ran GitHub workflow with response code: \(githubResponse.status.code)")
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

extension String {
    /// Turns IDs like `<@231391239>` to `231391239` like Discord expects.
    func makePlainID() -> String {
        if self.hasPrefix("<") && self.hasSuffix(">") {
            return String(self.dropFirst(2).dropLast())
        } else {
            return self
        }
    }
}
