@testable import DiscordBM
@testable import DiscordModels
import DiscordLogger
import SotoCore
import AsyncHTTPClient
@testable import Logging
@testable import Penny
import XCTest

public actor FakeMainService: MainService {
    public let manager: FakeManager
    public let cache: DiscordCache
    public let context: HandlerContext
    var botStateManager: BotStateManager {
        context.botStateManager
    }

    public init(manager: FakeManager) async throws {
        self.manager = manager
        var cacheStorage = DiscordCache.Storage()
        cacheStorage.guilds[TestData.vaporGuild.id] = TestData.vaporGuild
        self.cache = await DiscordCache(
            gatewayManager: manager,
            intents: [.guilds, .guildMembers],
            requestAllMembers: .enabled,
            storage: cacheStorage
        )
        self.context = try Self.makeContext(
            manager: manager,
            cache: cache
        )
    }

    public func bootstrapLoggingSystem(httpClient: HTTPClient) async throws { }

    public func makeBot(
        eventLoopGroup: any EventLoopGroup,
        httpClient: HTTPClient
    ) async throws -> any GatewayManager {
        return manager
    }

    public func makeCache(bot: any GatewayManager) async throws -> DiscordCache {
        return cache
    }

    public func beforeConnectCall(
        bot: any GatewayManager,
        cache: DiscordCache,
        httpClient: HTTPClient,
        awsClient: AWSClient
    ) async throws -> HandlerContext {
        await context.botStateManager.start(onStarted: { })
        return context
    }

    public func afterConnectCall(context: HandlerContext) async throws { }

    static func makeContext(
        manager: any GatewayManager,
        cache: DiscordCache
    ) throws -> HandlerContext {
        let discordService = DiscordService(
            discordClient: manager.client,
            cache: cache
        )
        let proposalsChecker = ProposalsChecker(
            proposalsService: FakeProposalsService(),
            discordService: discordService,
            queuedProposalsWaitTime: -1
        )
        let workers = HandlerContext.Workers(
            proposalsChecker: proposalsChecker,
            reactionCache: ReactionCache()
        )
        let services = HandlerContext.Services(
            usersService: FakeUsersService(),
            pingsService: FakePingsService(),
            faqsService: FakeFaqsService(),
            cachesService: FakeCachesService(workers: workers),
            discordService: discordService,
            renderClient: .init(
                renderer: try .forPenny(
                    on: (manager.client as! DefaultDiscordClient).client.eventLoopGroup.next()
                )
            )
        )
        return HandlerContext(
            services: services,
            workers: workers,
            botStateManager: BotStateManager(
                services: services,
                workers: workers,
                disabledDuration: .seconds(3)
            )
        )
    }

    public func waitForStateManagerShutdownAndDidShutdownSignals() async {
        /// Wait for the shutdown signal, then send a `didShutdown` signal.
        /// in practice, the `didShutdown` signal is sent by another Penny that is online.
        while let possibleSignal = await FakeResponseStorage.shared.awaitResponse(
            at: .createMessage(channelId: Constants.Channels.logs.id)
        ).value as? Payloads.CreateMessage {
            if let signal = possibleSignal.content,
               StateManagerSignal.shutdown.isInMessage(signal) {
                let content = await botStateManager._tests_didShutdownSignalEventContent()
                await manager.send(event: .init(
                    opcode: .dispatch,
                    data: .messageCreate(.init(
                        id: try! .makeFake(),
                        channel_id: Constants.Channels.logs.id,
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
                        attachments: [],
                        embeds: [],
                        pinned: false,
                        type: .default,
                        mentions: []
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
        XCTAssert(canRespond, "BotStateManager cache was too late to populate and enable responding")
    }
}

private extension DiscordTimestamp {
    static let fake = DiscordTimestamp(date: .distantPast)
    static let inFutureFake = DiscordTimestamp(date: .distantFuture)
}
