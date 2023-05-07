import DiscordModels
import Logging
import PennyModels

struct MessageHandler {
    let event: Gateway.MessageCreate
    var logger = Logger(label: "MessageHandler")
    var coinService: any CoinService {
        ServiceFactory.makeCoinService()
    }
    var pingsService: any AutoPingsService {
        ServiceFactory.makePingsService()
    }
    
    init(event: Gateway.MessageCreate) {
        self.event = event
        self.logger[metadataKey: "event"] = "\(event)"
    }
    
    func handle() async {
        /// Stop the bot from responding to other bots and itself
        if event.author?.bot == true { return }
        
        await checkForNewCoins()
        await checkForGuildSubscriptionCoins()
        await checkForPings()
    }
    
    func checkForNewCoins() async {
        guard let author = event.author else {
            logger.error("Cannot find author of the message")
            return
        }
        
        let sender = "<@\(author.id.value)>"
        let repliedUser = event.referenced_message?.value.author.map({ "<@\($0.id.value)>" })
        let coinHandler = CoinFinder(
            text: event.content,
            repliedUser: repliedUser,
            mentionedUsers: event.mentions.map(\.id).map({ "<@\($0.value)>" }),
            excludedUsers: [sender] // Can't give yourself a coin
        )
        let usersWithNewCoins = coinHandler.findUsers()
        // Return if there are no coins to be granted
        if usersWithNewCoins.isEmpty { return }
        
        var successfulResponses = [String]()
        successfulResponses.reserveCapacity(usersWithNewCoins.count)
        
        for receiver in usersWithNewCoins {
            let coinRequest = CoinRequest.AddCoin(
                // Possible to make this a variable later to include in the thanks message
                amount: 1,
                from: sender,
                receiver: receiver,
                source: .discord,
                reason: .userProvided
            )
            do {
                let response = try await self.coinService.postCoin(with: coinRequest)
                let responseString = "\(response.receiver) now has \(response.coins) \(Constants.vaporCoinEmoji)!"
                successfulResponses.append(responseString)
            } catch {
                logger.report("CoinService failed", error: error, metadata: [
                    "request": "\(coinRequest)"
                ])
            }
        }
        
        if successfulResponses.isEmpty {
            // Definitely there were some coin requests that failed.
            await self.respondToThanks(
                with: "Oops. Something went wrong! Please try again later",
                isAFailureMessage: true
            )
        } else {
            // Stitch responses together instead of sending a lot of messages,
            // to consume less Discord rate-limit.
            let finalResponse = successfulResponses.joined(separator: "\n")
            // Discord doesn't like embed-descriptions with more than 4_000 content length.
            if finalResponse.unicodeScalars.count > 4_000 {
                logger.warning("Can't send the full thanks-response", metadata: [
                    "full": .string(finalResponse)
                ])
                await self.respondToThanks(
                    with: "Coins were granted to a lot of members!",
                    isAFailureMessage: false
                )
            } else {
                await self.respondToThanks(with: finalResponse, isAFailureMessage: false)
            }
        }
    }
    
    /// Like server boosts.
    func checkForGuildSubscriptionCoins() async {
        guard event.type == .userPremiumGuildSubscription else { return }
        
        guard let author = event.author else {
            logger.error("Cannot find author of the message")
            return
        }
        
        let authorId = "<@\(author.id.value)>"
        let amount = 10
        let coinRequest = CoinRequest.AddCoin(
            // Possible to make this a variable later to include in the thanks message
            amount: amount,
            /// `from: GuildID` because it's not an actual user who gave the coins.
            from: "<@\(Constants.vaporGuildId.value)>",
            receiver: authorId,
            source: .discord,
            reason: .automationProvided
        )
        do {
            let response = try await self.coinService.postCoin(with: coinRequest)
            await self.respondToThanks(
                with: """
                \(authorId) Thanks for the Server Boost \(Constants.vaporLoveEmoji)!
                You now have \(amount) more \(Constants.vaporCoinEmoji) for a total of \(response.coins) \(Constants.vaporCoinEmoji)!
                """,
                overrideChannelId: Constants.thanksChannelId,
                isAFailureMessage: false
            )
        } catch {
            logger.report("CoinService failed for server boost thanks", error: error, metadata: [
                "request": "\(coinRequest)"
            ])
            /// Don't send a message at all in case of failure
        }
    }
    
    func checkForPings() async {
        if event.content.isEmpty { return }
        /// Check guild-id too, just to make sure / future-proofing.
        guard event.guild_id == Constants.vaporGuildId,
              let author = event.author,
              let member = event.member
        else { return }
        let authorId = author.id

        let expUsersDict: [S3AutoPingItems.Expression: Set<String>]
        do {
            expUsersDict = try await pingsService.getAll().items
        } catch {
            logger.report("Can't retrieve ping-words", error: error)
            return
        }
        let divided = event.content.divideForPingCommandExactMatchChecking()
        let folded = event.content.foldedForPingCommandContainmentChecking()
        /// `[UserID: [Expression]]`
        var usersToPing: [String: Set<S3AutoPingItems.Expression>] = [:]
        for exp in expUsersDict.keys {
            if Self.triggersPing(
                dividedForExactMatchChecking: divided,
                foldedForContainmentChecking: folded,
                expression: exp
            ), let users = expUsersDict[exp] {
                for userId in users {
                    /// Checks if the user is in the guild at all,
                    /// + if the user has read access of the channel.
                    if (try? await DiscordService.shared.userHasReadAccess(
                        userId: Snowflake(userId),
                        channelId: event.channel_id
                    )) == true {
                        usersToPing[userId, default: []].insert(exp)
                    }
                }
            }
        }

        let domain = "https://discord.com"
        let channelLink = "\(domain)/channels/\(Constants.vaporGuildId.value)/\(event.channel_id.value)"
        let messageLink = "\(channelLink)/\(event.id.value)"
        /// For now we don't need to worry about Discord rate-limits,
        /// `DiscordBM` will do enough and will try to not exceed them.
        /// If at some point this starts to hit rate-limits,
        /// we can just wait 1-2s before sending each message.
        for (userId, words) in usersToPing {
            /// Identify if this could be a test message by the bot-dev.
            let mightBeATestMessage = userId == Constants.botDevUserId.value
            && event.channel_id == Constants.logsChannelId
            
            if !mightBeATestMessage {
                /// Don't `@` someone for their own message.
                if userId == authorId.value { continue }
            }
            let authorName = makeAuthorName(
                nick: member.nick,
                username: author.username,
                id: author.id.value
            )

            await DiscordService.shared.sendDM(
                userId: Snowflake(userId),
                payload: .init(
                    embeds: [.init(
                        description: """
                        There is a new message that might be of interest to you.

                        By **\(authorName)** in \(channelLink)

                        Triggered by:
                        \(words.makeExpressionListForDiscord())
                        """,
                        color: .vaporPurple
                    )],
                    components: [[
                        .button(.init(
                            style: .link,
                            label: "Open Message",
                            url: messageLink
                        ))
                    ]]
                )
            )
        }
    }

    func makeAuthorName(nick: String?, username: String?, id: String) -> String {
        switch (nick, username) {
        case let (.some(nick), .some(username)) where nick != username:
            return "\(username) (aka \(nick))"
        case let (_, .some(username)):
            return username
        default:
            logger.warning("How could someone not have a username?!")
            return "<unnamed-member:@\(id)>"
        }
    }
    
    static func triggersPing(
        dividedForExactMatchChecking: [[Substring]],
        foldedForContainmentChecking: String,
        expression: S3AutoPingItems.Expression
    ) -> Bool {
        switch expression {
        case .matches(let match):
            let splitValue = match.split(whereSeparator: \.isWhitespace)
            return dividedForExactMatchChecking.contains(where: { $0.containsSequence(splitValue) })
        case .contains(let contain):
            return foldedForContainmentChecking.contains(contain)
        }
    }
    
    private func respondToThanks(
        with response: String,
        overrideChannelId channelId: ChannelSnowflake? = nil,
        isAFailureMessage: Bool
    ) async {
        await DiscordService.shared.sendThanksResponse(
            channelId: channelId ?? event.channel_id,
            replyingToMessageId: event.id,
            isAFailureMessage: isAFailureMessage,
            response: response
        )
    }
}
