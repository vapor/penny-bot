import AsyncHTTPClient
import DiscordBM
import GitHubAPI
import OpenAPIRuntime
import Rendering
import SharedServices
import Logging

struct HandlerContext {
    let eventName: GHEvent.Kind
    let event: GHEvent
    let httpClient: HTTPClient
    let discordClient: any DiscordClient
    let githubClient: Client
    let renderClient: RenderClient
    let messageLookupRepo: any MessageLookupRepo
    let usersService: any UsersService
    let logger: Logger
}

extension HandlerContext {
    func getDiscordMember(githubID: String) async throws -> Guild.Member? {
        guard let user = try await self.usersService.getUser(githubID: githubID) else {
            return nil
        }
        let response = try await self.discordClient.getGuildMember(
            guildId: Constants.guildID,
            userId: user.discordID
        )
        switch response.asError() {
        case let .jsonError(jsonError) where jsonError.code == .unknownMember:
            return nil
        default: break
        }
        return try response.decode()
    }
}
