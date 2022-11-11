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
    
    var logger: Logger!
    var canRespond = true
    let id = Date().timeIntervalSince1970
    
    let signal = "Hello the other Pennys 👋 you can retire now :)"
    var disableDuration = Duration.seconds(3 * 60)
    
    static private(set) var shared = BotStateManager()
    
    private init() { }
    
    func initialize(logger: Logger) {
        self.logger = logger
        Task { await send(content: signal) }
    }
    
    func canRespond(to event: Gateway.Event) -> Bool {
        checkIfItsASlowdownSignal(event: event)
        return canRespond
    }
    
    private func checkIfItsASlowdownSignal(event: Gateway.Event) {
        guard case let .messageCreate(message) = event.data,
              message.channel_id == Constants.internalChannelId,
              let author = message.author,
              author.id == Constants.botId,
              message.content.hasPrefix(signal)
        else { return }
        guard let otherId = message.content.split(whereSeparator: \.isNewline).last else {
            logger.warning("Can't find id of the other Penny")
            return
        }
        guard otherId != "\(self.id)" else { return }
        logger.warning("Received shutdown signal from another Penny")
        self.canRespond = false
        Task {
            try await Task.sleep(for: disableDuration)
            self.canRespond = true
            await send(content: "Wow! Why am I still alive?! I thought I should be retired by now!\nOn a real note though, **THIS IS AN ERROR. INVESTIGATE THE SITUATION**")
            logger.error("AWS has not yet shutdown this instance of Penny! Why?!")
        }
        Task {
            await send(content: "Ok the new Penny! I'll retire myself for a few minutes :)")
        }
    }
    
    private func send(content: String) async {
        await DiscordService.shared.sendMessage(
            channelId: Constants.internalChannelId,
            payload: .init(content: content + "\n\(self.id)")
        )
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