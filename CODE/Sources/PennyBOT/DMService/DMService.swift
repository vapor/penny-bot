import DiscordBM
import Logging

actor DMService {
    
    private var discordClient: DiscordClient!
    private var logger: Logger!
    /// `[UserDiscordID: DMChanelID]`
    private var channels: [String: String] = [:]
    
    private init () { }
    
    static let shared = DMService()
    
    func initialize(discordClient: DiscordClient, logger: Logger) {
        self.discordClient = discordClient
        self.logger = logger
    }
    
    func sendDM(userId: String, payload: DiscordChannel.CreateMessage) async {
        let userId = userId.makePlainUserID()
        guard let dmChannelID = await getDMChannelID(userId: userId) else { return }
        await self.sendMessage(channelId: dmChannelID, payload: payload)
    }
    
    private func getDMChannelID(userId: String) async -> String? {
        if let existing = channels[userId] {
            return existing
        } else {
            do {
                let dmChannel = try await discordClient.createDM(recipient_id: userId).decode()
                return dmChannel.id
            } catch {
                logger.error("Couldn't get DM channel for user: \(userId)")
                return nil
            }
        }
    }
    
    private func sendMessage(
        channelId: String,
        payload: DiscordChannel.CreateMessage
    ) async {
        do {
            let apiResponse = try await discordClient.createMessage(
                channelId: channelId,
                payload: payload
            )
            if !(200..<300).contains(apiResponse.httpResponse.status.code) {
                logger.error("Received non-200 status from Discord API: \(apiResponse)")
            }
        } catch {
            logger.error("Discord Client error: \(error)")
        }
    }
}
