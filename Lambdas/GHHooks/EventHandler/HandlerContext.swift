import AsyncHTTPClient
import DiscordBM
import GitHubAPI
import OpenAPIRuntime
import Rendering
import Logging

struct HandlerContext {
    let eventName: GHEvent.Kind
    let event: GHEvent
    let httpClient: HTTPClient
    let discordClient: any DiscordClient
    let githubClient: Client
    let renderClient: RenderClient
    let messageLookupRepo: any MessageLookupRepo
    let logger: Logger
}
