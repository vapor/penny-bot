@testable import DiscordBM
@testable import DiscordModels
@testable import Logging
@testable import Penny
import NIO
import DiscordLogger
import SotoCore
import AsyncHTTPClient
import SwiftTesting

actor FakeMainService: MainService {
    let manager: FakeManager
    let cache: DiscordCache
    let httpClient: HTTPClient
    let context: HandlerContext
    var botStateManager: BotStateManager {
        context.botStateManager
    }

    init(manager: FakeManager) async throws {
        self.manager = manager
        var cacheStorage = DiscordCache.Storage()
        cacheStorage.guilds[TestData.vaporGuild.id] = TestData.vaporGuild
        self.cache = await DiscordCache(
            gatewayManager: manager,
            intents: [.guilds, .guildMembers],
            requestAllMembers: .enabled,
            storage: cacheStorage
        )
        self.httpClient = HTTPClient(
            eventLoopGroup: MultiThreadedEventLoopGroup.singleton,
            configuration: .forPenny
        )
        self.context = try Self.makeContext(
            manager: manager,
            cache: cache,
            httpClient: httpClient
        )
    }

    func bootstrapLoggingSystem(httpClient: HTTPClient) async throws { }

    func makeBot(httpClient: HTTPClient) async throws -> any GatewayManager {
        return manager
    }

    func makeCache(bot: any GatewayManager) async throws -> DiscordCache {
        return cache
    }

    func beforeConnectCall(
        bot: any GatewayManager,
        cache: DiscordCache,
        httpClient: HTTPClient,
        awsClient: AWSClient
    ) async throws -> HandlerContext {
        await context.botStateManager.start(onStarted: { })
        return context
    }

    func afterConnectCall(context: HandlerContext) async throws { }

    static func makeContext(
        manager: any GatewayManager,
        cache: DiscordCache,
        httpClient: HTTPClient
    ) throws -> HandlerContext {
        let discordService = DiscordService(
            discordClient: manager.client,
            cache: cache
        )
        let evolutionChecker = EvolutionChecker(
            evolutionService: FakeEvolutionService(),
            discordService: discordService,
            queuedProposalsWaitTime: -1
        )
        let soChecker = SOChecker(
            soService: FakeSOService(),
            discordService: discordService
        )
        let reactionCache = ReactionCache()
        let autoFaqsService = FakeAutoFaqsService()
        let services = HandlerContext.Services(
            usersService: FakeUsersService(),
            pingsService: FakePingsService(),
            faqsService: FakeFaqsService(),
            autoFaqsService: autoFaqsService,
            cachesService: FakeCachesService(context: .init(
                autoFaqsService: autoFaqsService,
                evolutionChecker: evolutionChecker,
                soChecker: soChecker,
                reactionCache: reactionCache
            )),
            discordService: discordService,
            renderClient: .init(
                renderer: try .forPenny(
                    httpClient: httpClient,
                    logger: Logger(label: "Tests_Penny+Leaf+FakeService"),
                    on: httpClient.eventLoopGroup.next()
                )
            ),
            evolutionChecker: evolutionChecker,
            soChecker: soChecker,
            reactionCache: reactionCache
        )
        return HandlerContext(
            services: services,
            botStateManager: BotStateManager(
                services: services,
                disabledDuration: .seconds(3)
            )
        )
    }

    func waitForStateManagerShutdownAndDidShutdownSignals() async {
        /// Wait for the shutdown signal, then send a `didShutdown` signal.
        /// in practice, the `didShutdown` signal is sent by another Penny that is online.
        while let possibleSignal = await FakeResponseStorage.shared.awaitResponse(
            at: .createMessage(channelId: Constants.Channels.botLogs.id)
        ).value as? Payloads.CreateMessage {
            if let signal = possibleSignal.content,
               StateManagerSignal.shutdown.isInMessage(signal) {
                let content = await botStateManager._tests_didShutdownSignalEventContent()
                await manager.send(event: .init(
                    opcode: .dispatch,
                    data: .messageCreate(.init(
                        id: try! .makeFake(),
                        channel_id: Constants.Channels.botLogs.id,
                        author: DiscordUser(
                            id: Snowflake(Constants.botId),
                            username: "Penny",
                            discriminator: "#0"
                        ),
                        content: content,
                        timestamp: .fake,
                        tts: false,
                        mention_everyone: false,
                        mention_roles: [],
                        mentions: [],
                        attachments: [],
                        embeds: [],
                        pinned: false,
                        type: .default
                    ))
                ))
                break
            }
        }

        /// Wait to make sure the `BotStateManager` cache is already populated.
        for _ in 1...50 where !(await botStateManager.canRespond) {
            try? await Task.sleep(for: .milliseconds(50))
        }
        let canRespond = await botStateManager.canRespond
        #expect(canRespond, "BotStateManager cache was too late to populate and enable responding")
    }
}

private extension DiscordTimestamp {
    static let fake = DiscordTimestamp(date: .distantPast)
    static let inFutureFake = DiscordTimestamp(date: .distantFuture)
}
