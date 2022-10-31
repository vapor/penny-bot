import AsyncHTTPClient
import AWSLambdaRuntime
import AWSLambdaEvents
import DiscordBM
import Foundation
import NIOHTTP1
import PennyExtensions
import PennyRepositories
import PennyServices
import SotoCore
import PennyModels

enum GitHubRequestError: Error {
    case runWorkflowError(message: String)
}

enum DiscordRequestError: Error {
    case addMemberRoleError(message: String)
    case sendWelcomeMessageError(message: String)
}

struct HTTPClientFailedShutdownError: Error {
    let message = "Failed to shutdown HTTP Client"
}

@main
struct AddSponsor: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let httpClient: HTTPClient
    let awsClient: AWSClient
    let discordClient: DiscordClient

    init(context: LambdaInitializationContext) async throws {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        self.httpClient = httpClient
        let awsClient = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(httpClient.eventLoopGroup.next()))
        self.awsClient = awsClient
        context.terminator.register(name: "HTTP Client shutdown") { eventLoop in
            do {
                try httpClient.syncShutdown()
                try awsClient.syncShutdown()
                return eventLoop.makeSucceededVoidFuture()
            } catch {
                return eventLoop.makeFailedFuture(HTTPClientFailedShutdownError())
            }
        }
        // Get bot data from env vars
        guard let token = ProcessInfo.processInfo.environment["BOT_TOKEN"],
              let appId = ProcessInfo.processInfo.environment["BOT_APP_ID"] else {
            fatalError("Missing 'BOT_TOKEN' or 'BOT_APP_ID' env vars")
        }
        
        // Pull in Penny bot and use its Discord client
        let penny = BotGatewayManager(
            eventLoopGroup: httpClient.eventLoopGroup,
            httpClient: httpClient,
            token: token,
            appId: appId,
            intents: [.guildMessages, .messageContent]
        )
        self.discordClient = penny.client
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        
        // Only accept sponsorship events
        guard event.headers["X-Github-Event"] == "sponsorship" else {
            return APIGatewayV2Response(statusCode: HTTPResponseStatus(code: 200))
        }
        let apiGatewayResponse: APIGatewayV2Response
        do {
            // Try updating the GitHub Readme with the new sponsor
            try await requestReadmeWorkflowTrigger(on: event, context: context)
            
            // Decode GitHub Webhook Response
            let payload: GitHubWebhookPayload = try event.bodyObject()
            
            // Look for the user in the DB
            let newSponsorID = payload.sender.id
            let userService = UserService(awsClient, context.logger)
            let user = try await userService.getUserWith(githubID: String(newSponsorID))
            guard let user = user else {
                apiGatewayResponse = APIGatewayV2Response(
                    statusCode: .notFound,
                    body: "Error: there is no user with GitHub ID \(newSponsorID)"
                )
                return apiGatewayResponse
            }
            
            guard let userDiscordID = user.discordID else {
                apiGatewayResponse = APIGatewayV2Response(
                    statusCode: .notFound,
                    body: "Error: user \(newSponsorID) did not link a Discord account"
                )
                return apiGatewayResponse
            }
            
            // Get role ID based on sponsorship tier
            let role = try SponsorType.for(sponsorshipAmount: payload.sponsorship.tier.monthlyPriceInCents)
            
            // Add roles to new sponsor
            try await addRole(to: userDiscordID, from: payload, role: role, context: context)
            
            // If it's a sponsor, we need to add the backer role too
            if role == .sponsor {
                try await addRole(to: userDiscordID, from: payload, role: .backer, context: context)
            }
            
            // Send message to new sponsor
            try await sendMessage(to: userDiscordID, from: payload, role: role, context: context)

        } catch let error {
            apiGatewayResponse = APIGatewayV2Response(
                statusCode: .badRequest,
                body: "Error: \(error.localizedDescription)"
            )
            return apiGatewayResponse
        }
    }
    
    /**
     Adds a new Discord role to the selected user, depending on the sponsorship tier they selected (**sponsor**, **backer**).
     */
    private func addRole(
        to userDiscordID: String,
        from githubPayload: GitHubWebhookPayload,
        role: SponsorType,
        context: LambdaContext
    ) async throws {
        // Try adding role to new sponsor
        let addRoleResponse = try await discordClient.addGuildMemberRole(
            guildId: "431917998102675485",
            userId: userDiscordID,
            roleId: role.roleID
        )
        
        // Throw if adding new role response is invalid
        guard 200...299 ~= addRoleResponse.status.code else {
            throw DiscordRequestError.addMemberRoleError(
                message: "Failed to add \(role.rawValue) role to member with error: \(addRoleResponse.status.description)"
            )
        }
        
        context.logger.info("Successfully added \(role.rawValue) role to user \(userDiscordID) with response code: \(addRoleResponse.status.code)")
    }

    /**
     Sends a message welcoming the user in the new channel and giving them a coin.
     */
    private func sendMessage(
        to userDiscordID: String,
        from githubPayload: GitHubWebhookPayload,
        role: SponsorType,
        context: LambdaContext
    ) async throws {
        // Try sending message to new sponsor
        let createMessageResponse = try await discordClient.createMessage(
            // Always send message to backer channel only
            channelId: SponsorType.backer.channelID,
            payload: .init(
                embeds: [.init(
                    description: "Welcome <@\(userDiscordID)>, our new \(role.rawValue)"
                )]
            )
        )
        
        // Throw if response is invalid
        guard 200...299 ~= createMessageResponse.httpResponse.status.code else {
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
        let url = "https://api.github.com/repos/vapor/vapor/actions/workflows/sponsor.yml/dispatches"
        var triggerActionRequest = HTTPClientRequest(url: url)
        triggerActionRequest.method = .POST
        
        // The token is going to have to be in the SecretsManager in AWS
        triggerActionRequest.headers.add(contentsOf: [
            "Accept": "application/vnd.github+json",
            "Authorization": "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"
        ])
        
        // Send request to trigger workflow and read response
        let githubResponse = try await httpClient.execute(triggerActionRequest, timeout: .seconds(10))
        
        guard 200...299 ~= githubResponse.status.code else {
            throw GitHubRequestError.runWorkflowError(
                message: "GitHub did not run workflow with error code: \(githubResponse.status.code)"
            )
        }
        
        context.logger.info("Successfully ran GitHub workflow with response code: \(githubResponse.status.code)")
    }
}

