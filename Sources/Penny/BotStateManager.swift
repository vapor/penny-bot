import DiscordBM
import Foundation
import Logging

/*
 When we update Penny, AWS waits a few minutes before taking down the old Penny instance to
 make sure the new instance is healthy.
 This makes it so there is a short period where there are 2 Penny bots that will respond to
 Discord Gateway events.
 This actor's job is to prevent that. Only the new bot should respond to events.
 */
actor BotStateManager {
    
    var logger = Logger(label: "BotStateManager")
    var canRespond = true
    let id = Int(Date().timeIntervalSince1970)
    
    let shutdownSignal = "Hello the other Pennys 👋 you can retire now :)"
    let didShutdownSignal = "I'm retired!"
    var disableDuration = Duration.seconds(3 * 60)
    
    static private(set) var shared = BotStateManager()
    
    private init() { }
    
    func initialize() {
        self.logger[metadataKey: "id"] = "\(self.id)"
        Task { await send(shutdownSignal) }
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
        if message.content.hasPrefix(shutdownSignal) {
            shutdown()
        } else if message.content.hasPrefix(didShutdownSignal) {
            
        } else {
            logger.error("Unknown signal")
            return
        }
    }

    private func shutdown() {
        logger.warning("Received shutdown signal from another Penny")
        self.canRespond = false
        Task {
            try await Task.sleep(for: disableDuration)
            self.canRespond = true
            logger.error("AWS has not yet shutdown this instance of Penny! Why?!")
        }
    }

    private func send(_ text: String) async {
        await DiscordService.shared.sendMessage(
            channelId: Constants.Channels.logs.id,
            payload: .init(content: text + " \(self.id)")
        )
    }
    
#if DEBUG
    func _tests_reset() {
        BotStateManager.shared = BotStateManager()
    }
    
    func _tests_setDisableDuration(to duration: Duration) {
        self.disableDuration = duration
    }
#endif
}
