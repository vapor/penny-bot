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
    
    var discordClient: (any DiscordClient)!
    var logger: Logger!
    var canRespond = true
    let id = Int(Date().timeIntervalSince1970)
    
    let signal = "Hello the other Pennys 👋 you can retire now :)"
    var disableDuration = Duration.seconds(3 * 60)
    
    static private(set) var shared = BotStateManager()
    
    private init() { }
    
    func initialize(discordClient: any DiscordClient, logger: Logger) {
        self.discordClient = discordClient
        self.logger = logger
        self.logger[metadataKey: "id"] = "\(self.id)"
        Task { await sendSignal() }
    }
    
    func canRespond(to event: Gateway.Event) -> Bool {
        checkIfItsASlowdownSignal(event: event)
        return canRespond
    }
    
    private func checkIfItsASlowdownSignal(event: Gateway.Event) {
        guard case let .messageCreate(message) = event.data,
              message.channel_id == Constants.logsChannelId,
              let author = message.author,
              author.id == Constants.botId,
              message.content.hasPrefix(signal)
        else { return }
        guard let otherId = message.content.split(whereSeparator: \.isWhitespace).last else {
            logger.warning("Can't find id of the other Penny")
            return
        }
        if otherId == "\(self.id)" { return }
        logger.warning("Received shutdown signal from another Penny")
        self.canRespond = false
        Task {
            try await Task.sleep(for: disableDuration)
            self.canRespond = true
            logger.error("AWS has not yet shutdown this instance of Penny! Why?!")
        }
    }
    
    private func sendSignal() async {
        // The DiscordClient will retry the request too in some situations,
        // so we shouldn't need to retry it ourselves.
        do {
            let response = try await discordClient.createMessage(
                channelId: Constants.logsChannelId,
                payload: .init(content: signal + " \(self.id)")
            )
            do {
                try response.guardIsSuccessfulResponse()
            } catch {
                logger.report("BotStateManager received bad response", response: response)
            }
        } catch {
            logger.error("BotStateManager received error", metadata: ["error": "\(error)"])
        }
    }
    
#if DEBUG
    func tests_reset() {
        BotStateManager.shared = BotStateManager()
    }
    
    func tests_setDisableDuration(to duration: Duration) {
        self.disableDuration = duration
    }
#endif
}
