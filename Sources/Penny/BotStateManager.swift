import DiscordBM
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging

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

    var canRespond = false
    var onStarted: (() async -> Void)?

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

    func start(onStarted: @Sendable @escaping () async -> Void) async {
        self.onStarted = onStarted
        Task { await send(.shutdown) }
        cancelIfCachePopulationTakesTooLong()
    }

    private func cancelIfCachePopulationTakesTooLong() {
        Task {
            try await Task.sleep(for: .seconds(120))
            if !canRespond {
                await startAllowingResponses()
                logger.error("No CachesStorage-population was done in-time")
            }
        }
    }

    func canRespond(to event: Gateway.Event) -> Bool {
        checkIfItsASignal(event: event)
        return canRespond
    }
    
    private func checkIfItsASignal(event: Gateway.Event) {
        guard case let .messageCreate(message) = event.data,
              message.channel_id == Constants.Channels.botLogs.id,
              let author = message.author,
              author.id == Constants.botId,
              let otherId = message.content.split(whereSeparator: \.isWhitespace).last
        else { return }
        if otherId == "\(self.id)" { return }

        if StateManagerSignal.shutdown.isInMessage(message.content) {
            logger.trace("Received 'shutdown' signal")
            shutdown()
        } else if StateManagerSignal.didShutdown.isInMessage(message.content) {
            logger.trace("Received 'didShutdown' signal")
            populateCache()
        }
    }

    private func shutdown() {
        Task {
            await context.cachesService.gatherCachedInfoAndSaveToRepository()
            await send(.didShutdown)
            self.canRespond = false

            try await Task.sleep(for: disableDuration)
            await startAllowingResponses()
            logger.critical("AWS has not yet shutdown this instance of Penny! Why?!")
        }
    }

    private func populateCache() {
        Task {
            if canRespond {
                logger.warning("Received a did-shutdown signal but Cache is already populated")
            } else {
                await context.cachesService.getCachedInfoFromRepositoryAndPopulateServices()
                await startAllowingResponses()
            }
        }
    }

    private func startAllowingResponses() async {
        canRespond = true
        await onStarted?()
    }

    private func send(_ signal: StateManagerSignal) async {
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
