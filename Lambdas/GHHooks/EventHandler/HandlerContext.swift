import DiscordBM
import OpenAPIRuntime

struct HandlerContext {
    let eventName: GHEvent.Kind
    let event: GHEvent
    let discordClient: any DiscordClient
    let githubClient: Client
}
