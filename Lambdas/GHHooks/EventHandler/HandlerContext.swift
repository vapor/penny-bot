import AsyncHTTPClient
import DiscordBM
import OpenAPIRuntime
import Logging

struct HandlerContext {
    let eventName: GHEvent.Kind
    let event: GHEvent
    let httpClient: HTTPClient
    let discordClient: any DiscordClient
    let githubClient: Client
    let logger: Logger
}
