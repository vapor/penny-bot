import DiscordBM
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
import ServiceLifecycle

/**
 When we update Penny, AWS waits a few minutes before taking down the old Penny instance to
 make sure the new instance is healthy.
 This makes it so there is a short period where there are 2 Penny bots that will respond to
 Discord Gateway events.
 This actor's job is to prevent that. Only the new bot should respond to events.

 This will:
   * Disallow Gateway-event handling from the beginning.
   * When `initialize()` is called, this will send a "please shutdown" message.
   * When the old Penny instance receive that message.
     * The old instance will save all needed cached stuff into a S3 bucket.
     * Then it will send a "did shutdown" message.
   * The new instance will catch the "did shutdown" message.
     * The new instance will get the stuff from the S3 bucket.
     * Then it will start allowing Gateway-event handlings.
   * If the old instance is too slow to make the process happen, the process is aborted and
     the new instance will start handling events without waiting more for the old instance.
 */
actor BotStateManager {
    let id = Int(Date().timeIntervalSince1970)
    let context: HandlerContext
    let disableDuration: Duration
    let logger: Logger
    private var cachesPopulationContinuations: [CheckedContinuation<Void, Never>] = []

    var canRespond = false

    init(
        context: HandlerContext,
        disabledDuration: Duration = .seconds(3 * 60)
    ) {
        self.context = context
        self.disableDuration = disabledDuration
        var logger = Logger(label: "BotStateManager")
        logger[metadataKey: "id"] = "\(self.id)"
        self.logger = logger
    }

    func start() {
        switch Constants.deploymentEnvironment {
        case .local:
            break
        case .prod:
            self.context.backgroundProcessor.process {
                await self.cancelIfCachePopulationTakesTooLong()
            }
            self.context.backgroundProcessor.process {
                await self.send(.shutdown)
            }
        }
    }

    func addCachesPopulationWaiter(_ cont: CheckedContinuation<Void, Never>) {
        switch self.canRespond {
        case true:
            cont.resume()
        case false:
            self.cachesPopulationContinuations.append(cont)
        }
    }

    private func cancelIfCachePopulationTakesTooLong() async {
        guard (try? await Task.sleep(for: .seconds(120))) != nil else {
            return /// cancelled
        }
        if !canRespond {
            await startAllowingResponses()
            logger.error("No CachesStorage-population was done in-time")
        }
    }

    func canRespond(to event: Gateway.Event) async -> Bool {
        if Constants.deploymentEnvironment == .prod {
            await checkIfItsASignal(event: event)
        }
        return canRespond
    }
    
    private func checkIfItsASignal(event: Gateway.Event) async {
        guard case let .messageCreate(message) = event.data,
              message.channel_id == Constants.Channels.botLogs.id,
              let author = message.author,
              author.id == Constants.botId,
              let otherId = message.content.split(whereSeparator: \.isWhitespace).last,
              otherId != "\(self.id)"
        else { return }

        if StateManagerSignal.shutdown.isInMessage(message.content) {
            logger.trace("Received 'shutdown' signal")
            await shutdown()
        } else if StateManagerSignal.didShutdown.isInMessage(message.content) {
            logger.trace("Received 'didShutdown' signal")
            self.context.backgroundProcessor.process {
                await self.populateCache()
            }
        }
    }

    private func shutdown() async {
        await context.cachesService.gatherCachedInfoAndSaveToRepository()
        await send(.didShutdown)
        self.canRespond = false

        guard (try? await Task.sleep(for: disableDuration)) != nil else {
            return /// cancelled
        }

        await startAllowingResponses()
        logger.critical("AWS has not yet shutdown this instance of Penny! Why?!")
    }

    private func populateCache() async {
        if canRespond {
            logger.warning("Received a did-shutdown signal but Cache is already populated")
        } else {
            await context.cachesService.getCachedInfoFromRepositoryAndPopulateServices()
            await startAllowingResponses()
        }
    }

    private func startAllowingResponses() async {
        let continuations = self.cachesPopulationContinuations
        self.cachesPopulationContinuations.removeAll()
        self.canRespond = true
        for continuation in continuations {
            continuation.resume()
        }
    }

    private func send(_ signal: StateManagerSignal) async {
        guard Constants.deploymentEnvironment == .prod else { return }

        let content = makeSignalMessage(text: signal.rawValue, id: self.id)
        await context.discordService.sendMessage(
            channelId: Constants.Channels.botLogs.id,
            payload: .init(content: content)
        )
    }

    func makeSignalMessage(text: String, id: Int) -> String {
        "\(text) \(id)"
    }

    func _tests_didShutdownSignalEventContent() -> String {
        makeSignalMessage(text: StateManagerSignal.didShutdown.rawValue, id: self.id - 10)
    }
}

enum StateManagerSignal: String {
    case shutdown = "Hello the other Pennys 👋 you can retire now :)"
    case didShutdown = "I'm retired!"

    func isInMessage(_ text: String) -> Bool {
        text.hasPrefix(self.rawValue)
    }
}
