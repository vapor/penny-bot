import DiscordBM
import Logging

actor DiscordService {
    
    private var discordClient: (any DiscordClient)!
    private var logger: Logger!
    /// `[UserDiscordID: DMChanelID]`
    private var channels: [String: String] = [:]
    
    private init () { }
    
    static let shared = DiscordService()
    
    func initialize(discordClient: any DiscordClient, logger: Logger) {
        self.discordClient = discordClient
        self.logger = logger
    }
    
    func sendDM(userId: String, payload: RequestBody.CreateMessage) async {
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
    
    func sendMessage(
        channelId: String,
        payload: RequestBody.CreateMessage
    ) async {
        do {
            let response = try await discordClient.createMessage(
                channelId: channelId,
                payload: payload
            )
            try response.guardIsSuccessfulResponse()
        } catch {
            logger.error("Couldn't send a message. Error: \(error)")
        }
    }
    
    /// Returns whether or not the response has been successfully sent.
    func respondToInteraction(
        id: String,
        token: String,
        payload: RequestBody.InteractionResponse
    ) async -> Bool {
        do {
            let response = try await discordClient.createInteractionResponse(
                id: id,
                token: token,
                payload: payload
            )
            try response.guardIsSuccessfulResponse()
            return true
        } catch {
            logger.error("Couldn't send interaction response. Error: \(error)")
            return false
        }
    }
    
    func editInteraction(
        token: String,
        payload: RequestBody.InteractionResponse.CallbackData
    ) async {
        do {
            let response = try await discordClient.editInteractionResponse(
                token: token,
                payload: payload
            )
            try response.guardIsSuccessfulResponse()
        } catch {
            logger.error("Couldn't send interaction edit. Error: \(error)")
        }
    }
    
    func createSlashCommand(payload: ApplicationCommand) async {
        do {
            let response = try await discordClient.createApplicationGlobalCommand(
                payload: payload
            )
            try response.guardIsSuccessfulResponse()
        } catch {
            logger.error("Couldn't create slash command. Error: \(error)")
        }
    }
    
    func getChannelMessage(
        channelId: String,
        messageId: String
    ) async -> Gateway.MessageCreate? {
        do {
            return try await discordClient.getChannelMessage(
                channelId: channelId,
                messageId: messageId
            ).decode()
        } catch {
            logger.error("Couldn't get channel message. Error: \(error)")
            return nil
        }
    }
}
