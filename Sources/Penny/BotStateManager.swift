import DiscordBM
import Foundation
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
     * The old instance will cache save all needed cached stuff into a S3 bucket.
     * Then it will send a "did shutdown" message.
   * The new instance will catch the "did shutdown" message.
     * The new instance will get the stuff from the S3 bucket.
     * Then it will start allowing Gateway-event handlings.
   * If the old instance is too slow to make the process happen, the process is aborted and
     the new instance will start handling events without waiting more for the old instance.
 */
actor BotStateManager {
    
    var logger = Logger(label: "BotStateManager")
    var canRespond = false
    let id = Int(Date().timeIntervalSince1970)

    var cachesService: any CachesService {
        ServiceFactory.makeCachesService()
    }

    var disableDuration = Duration.seconds(3 * 60)

    var isCachePopulated = false

    static private(set) var shared = BotStateManager()
    
    private init() { }
    
    func initialize() async {
        self.logger[metadataKey: "id"] = "\(self.id)"
        Task { await send(.shutdown) }
        cancelIfCachePopulationTakesTooLong()
    }

    func cancelIfCachePopulationTakesTooLong() {
        Task {
            try await Task.sleep(for: .seconds(15))
            if !isCachePopulated {
                canRespond = true
                logger.error("No CacheStorage-population signal was done in-time")
            }
        }
    }

    func canRespond(to event: Gateway.Event) -> Bool {
        checkIfItsASignal(event: event)
        return canRespond
    }
    
    private func checkIfItsASignal(event: Gateway.Event) {
        guard case let .messageCreate(message) = event.data,
              message.channel_id == Constants.Channels.logs.id,
              let author = message.author,
              author.id.rawValue == Constants.botId
        else { return }
        guard let otherId = message.content.split(whereSeparator: \.isWhitespace).last else {
            logger.warning("Can't find id of the other Penny")
            return
        }
        if otherId == "\(self.id)" { return }
        if message.content.hasPrefix(StateManagerSignal.shutdown.value) {
            shutdown()
        } else if message.content.hasPrefix(StateManagerSignal.didShutdown.value) {
            populateCache()
        } else {
            logger.error("Unknown signal")
            return
        }
    }

    private func shutdown() {
        logger.warning("Received shutdown signal from another Penny")
        self.canRespond = false
        Task {
            await cachesService.gatherCachedInfoAndSaveToRepository()
            await send(.didShutdown)

            try await Task.sleep(for: disableDuration)
            self.canRespond = true
            logger.error("AWS has not yet shutdown this instance of Penny! Why?!")
        }
    }

    private func populateCache() {
        Task {
            if isCachePopulated {
                logger.warning("Received a did-shutdown signal but Cache is already populated")
            } else {
                isCachePopulated = true
                canRespond = true
                await cachesService.getCachedInfoFromRepositoryAndPopulateServices()
            }
        }
    }

    private func send(_ signal: StateManagerSignal) async {
        await DiscordService.shared.sendMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(
                content: makeSignalMessage(text: signal.value, id: self.id)
            )
        )
    }

    func makeSignalMessage(text: String, id: Int) -> String {
        "\(text) \(id)"
    }

#if DEBUG
    func _tests_reset() {
        BotStateManager.shared = BotStateManager()
    }
    
    func _tests_setDisableDuration(to duration: Duration) {
        self.disableDuration = duration
    }

    func _tests_didShutdownSignalEventContent() -> String {
        makeSignalMessage(text: StateManagerSignal.didShutdown.value, id: self.id - 10)
    }
#endif
}

enum StateManagerSignal {
    case shutdown
    case didShutdown

    var value: String {
        switch self {
        case .shutdown:
            return "Hello the other Pennys 👋 you can retire now :)"
        case .didShutdown:
            return "I'm retired!"
        }
    }
}
