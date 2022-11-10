import DiscordBM
import Logging
import PennyModels

struct MessageHandler {
    
    let coinService: any CoinService
    let logger: Logger
    let event: Gateway.MessageCreate
    
    func handle() async {
        await checkForNewCoins()
        await checkForPings()
    }
    
    func checkForNewCoins() async {
        guard let author = event.author else {
            logger.error("Cannot find author of the message. Event: \(event)")
            return
        }
        
        // Stop the bot from responding to other bots and itself
        if author.bot == true {
            return
        }
        
        let sender = "<@\(author.id)>"
        let repliedUser = event.referenced_message?.value.author.map({ "<@\($0.id)>" })
        let coinHandler = CoinHandler(
            text: event.content,
            repliedUser: repliedUser,
            mentionedUsers: event.mentions.map(\.id).map({ "<@\($0)>" }),
            excludedUsers: [sender] // Can't give yourself a coin
        )
        let usersWithNewCoins = coinHandler.findUsers()
        // Return if there are no coins to be granted
        if usersWithNewCoins.isEmpty { return }
        
        var successfulResponses = [String]()
        successfulResponses.reserveCapacity(usersWithNewCoins.count)
        
        for receiver in usersWithNewCoins {
            let coinRequest = CoinRequest(
                // Possible to make this a variable later to include in the thanks message
                amount: 1,
                from: sender,
                receiver: receiver,
                source: .discord,
                reason: .userProvided
            )
            do {
                let response = try await self.coinService.postCoin(with: coinRequest)
                let responseString = "\(response.receiver) now has \(response.coins) coins!"
                successfulResponses.append(responseString)
            } catch {
                logger.error("CoinService failed. Request: \(coinRequest), Error: \(error)")
            }
        }
        
        if successfulResponses.isEmpty {
            // Definitely there were some coin requests that failed.
            await self.respond(with: "Oops. Something went wrong! Please try again later")
        } else {
            // Stitch responses together instead of sending a lot of messages,
            // to consume less Discord rate-limit.
            let finalResponse = successfulResponses.joined(separator: "\n")
            // Discord doesn't like embed-descriptions with more than 4_000 content length.
            if finalResponse.unicodeScalars.count > 4_000 {
                await self.respond(with: "Coins were granted to a lot of members!")
            } else {
                await self.respond(with: finalResponse)
            }
        }
    }
    
    func checkForPings() async {
        if event.content.isEmpty { return }
        guard let guildId = event.guild_id else { return }
        #warning("fix these")
        let words: Set<String> = { fatalError("PINGS - to be implemented") }()
        /// `[Word: [Users]]`
        let wordPeople: [String: Set<String>] = { fatalError("PINGS - to be implemented") }()
        let folded = event.content.foldForPingCommand()
        /// `[UserID: [PingTrigger]]`
        var usersToPing: [String: Set<String>] = [:]
        for word in words {
            if folded.contains(word),
               let users = wordPeople[word] {
                for user in users {
                    usersToPing[user, default: []].insert(word)
                }
            }
        }
        let messageLink = "https://discord.com/channels/\(guildId)/\(event.channel_id)/\(event.id)"
        for (user, words) in usersToPing {
            let words = words.sorted().map { "`\($0)`" }.joined(separator: ", ")
            await DiscordService.shared.sendDM(
                userId: user,
                payload: .init(
                    embeds: [.init(
                        description: """
                        There is a new message that might be of interest to you.
                        Triggered by: \(words)
                        Link: \(messageLink)
                        """,
                        color: .vaporPurple
                    )]
                )
            )
        }
    }
    
    private func respond(with response: String) async {
        await DiscordService.shared.sendMessage(
            channelId: event.channel_id,
            payload: .init(
                embeds: [.init(
                    description: response,
                    color: .vaporPurple
                )],
                message_reference: .init(
                    message_id: event.id,
                    channel_id: event.channel_id,
                    guild_id: event.guild_id,
                    fail_if_not_exists: false
                )
            )
        )
    }
}
