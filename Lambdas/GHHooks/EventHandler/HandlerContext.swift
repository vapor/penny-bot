import AsyncHTTPClient
import DiscordBM
import GitHubAPI
import LambdasShared
import Logging
import OpenAPIRuntime
import Rendering
import Shared

struct HandlerContext: Sendable {
    let eventName: GHEvent.Kind
    let event: GHEvent
    let httpClient: HTTPClient
    let discordClient: any DiscordClient
    let githubClient: Client
    let renderClient: RenderClient
    let messageLookupRepo: any MessageLookupRepo
    let usersService: any UsersService
    let requester: any GenericRequester
    let secretsRetriever: any GenericSecretsRetriever
    var logger: Logger

    init(
        eventName: GHEvent.Kind,
        event: GHEvent,
        httpClient: HTTPClient,
        discordClient: any DiscordClient,
        githubClient: Client,
        renderClient: RenderClient,
        messageLookupRepo: any MessageLookupRepo,
        usersService: any UsersService,
        requester: any GenericRequester,
        secretsRetriever: any GenericSecretsRetriever,
        logger: Logger
    ) {
        self.eventName = eventName
        self.event = event
        self.httpClient = httpClient
        self.discordClient = discordClient
        self.githubClient = githubClient
        self.renderClient = renderClient
        self.messageLookupRepo = messageLookupRepo
        self.usersService = usersService
        self.requester = requester
        self.secretsRetriever = secretsRetriever
        self.logger = logger
    }

    init(
        eventName: GHEvent.Kind,
        event: GHEvent,
        httpClient: HTTPClient,
        discordClient: any DiscordClient,
        githubClient: Client,
        renderClient: RenderClient,
        messageLookupRepo: any MessageLookupRepo,
        usersService: any UsersService,
        secretsRetriever: any GenericSecretsRetriever,
        logger: Logger
    ) {
        self.eventName = eventName
        self.event = event
        self.httpClient = httpClient
        self.discordClient = discordClient
        self.githubClient = githubClient
        self.renderClient = renderClient
        self.messageLookupRepo = messageLookupRepo
        self.usersService = usersService
        self.requester = Requester(
            eventName: eventName,
            event: event,
            httpClient: httpClient,
            discordClient: discordClient,
            githubClient: githubClient,
            usersService: usersService,
            logger: logger
        )
        self.secretsRetriever = secretsRetriever
        self.logger = logger
    }
}
