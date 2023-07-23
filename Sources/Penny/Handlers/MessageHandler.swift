import DiscordBM
import Logging
import Models

struct MessageHandler {
    let event: Gateway.MessageCreate
    var logger = Logger(label: "MessageHandler")
    var coinService: any CoinService {
        ServiceFactory.makeCoinService()
    }
    var pingsService: any AutoPingsService {
        ServiceFactory.makePingsService()
    }
    var discordService: DiscordService {
        DiscordService.shared
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

        let coinHandler = CoinFinder(
            text: event.content,
            repliedUser: event.referenced_message?.value.author?.id,
            mentionedUsers: event.mentions.map(\.id),
            excludedUsers: [author.id] // Can't give yourself a coin
        )
        let usersWithNewCoins = coinHandler.findUsers()
        // Return if there are no coins to be granted
        if usersWithNewCoins.isEmpty { return }
        
        var successfulResponses = [String]()
        successfulResponses.reserveCapacity(usersWithNewCoins.count)
        
        for receiver in usersWithNewCoins {
            let coinRequest = CoinRequest.DiscordCoinEntry(
                amount: 1,
                fromDiscordID: author.id,
                toDiscordID: receiver,
                source: .discord,
                reason: .userProvided
            )
            do {
                let response = try await self.coinService.postCoin(with: coinRequest)
                let responseString = "\(DiscordUtils.mention(id: response.receiver)) now has \(response.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!"
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
                isFailureMessage: true
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
                    isFailureMessage: false
                )
            } else {
                await self.respondToThanks(with: finalResponse, isFailureMessage: false)
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

        let amount = 10
        let coinRequest = CoinRequest.DiscordCoinEntry(
            amount: amount,
            /// Guild-id because it's not an actual user who gave the coins.
            fromDiscordID: UserSnowflake(Constants.vaporGuildId),
            toDiscordID: author.id,
            source: .discord,
            reason: .automationProvided
        )
        do {
            let response = try await self.coinService.postCoin(with: coinRequest)
            await self.respondToThanks(
                with: """
                \(DiscordUtils.mention(id: author.id)) Thanks for the Server Boost \(Constants.ServerEmojis.love.emoji)!
                You now have \(amount) more \(Constants.ServerEmojis.coin.emoji) for a total of \(response.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!
                """,
                overrideChannelId: Constants.Channels.thanks.id,
                isFailureMessage: false,
                userToExplicitlyMention: author.id
            )
        } catch {
            logger.report("CoinService failed for server boost thanks", error: error, metadata: [
                "request": "\(coinRequest)"
            ])
            /// Don't send a message at all in case of failure
        }
    }
    
    func checkForPings() async {
        let content = event.content
        if content.isEmpty { return }
        guard let guildId = event.guild_id,
              let author = event.author,
              let member = event.member
        else { return }

        let expUsersDict: [S3AutoPingItems.Expression: Set<UserSnowflake>]
        do {
            expUsersDict = try await pingsService.getAll().items
        } catch {
            logger.report("Can't retrieve ping-words", error: error)
            return
        }
        let divided = content.divideForPingCommandExactMatchChecking()
        let folded = content.foldedForPingCommandContainmentChecking()
        /// `[UserID: [Expression]]`
        var usersToPing: [UserSnowflake: Set<S3AutoPingItems.Expression>] = [:]
        for exp in expUsersDict.keys {
            if Self.triggersPing(
                dividedForExactMatchChecking: divided,
                foldedForContainmentChecking: folded,
                expression: exp
            ), let users = expUsersDict[exp] {
                for userId in users {
                    /// Checks if the user is in the guild at all,
                    /// + if the user has read access of the channel.
                    if (try? await discordService.userHasReadAccess(
                        userId: Snowflake(userId),
                        channelId: event.channel_id
                    )) == true {
                        usersToPing[userId, default: []].insert(exp)
                    }
                }
            }
        }

        let domain = "https://discord.com"
        let channelLink = "\(domain)/channels/\(Constants.vaporGuildId.rawValue)/\(event.channel_id.rawValue)"
        let messageLink = "\(channelLink)/\(event.id.rawValue)"
        /// For now we don't need to worry about Discord rate-limits,
        /// `DiscordBM` will do enough and will try to not exceed them.
        /// If at some point this starts to hit rate-limits,
        /// we can just wait 1-2s before sending each message.
        for (userId, words) in usersToPing {
            /// Identify if this could be a test message by the bot-dev.
            let mightBeATestMessage = userId == Constants.botDevUserId
            && event.channel_id == Constants.Channels.logs.id
            
            if !mightBeATestMessage {
                /// Don't `@` someone for their own message.
                if userId == author.id { continue }
            }
            let authorName = makeAuthorName(nick: member.nick, user: author)
            let iconUrlEndpoint = member.avatar.map { avatar in
                CDNEndpoint.guildMemberAvatar(
                    guildId: guildId,
                    userId: author.id,
                    avatar: avatar
                )
            } ?? author.avatar.map { avatar in
                CDNEndpoint.userAvatar(
                    userId: author.id,
                    avatar: avatar
                )
            }
            await discordService.sendDM(
                userId: Snowflake(userId),
                payload: .init(
                    embeds: [.init(
                        description: """
                        There is a new message in \(channelLink) that might be of interest to you.

                        Triggered by:
                        \(words.makeExpressionListForDiscord())

                        >>> \(content.unicodesPrefix(256))
                        """,
                        color: .blue,
                        footer: .init(
                            text: "By \(authorName)",
                            icon_url: (iconUrlEndpoint?.url).map { .exact($0) }
                        )
                    )],
                    components: [[.button(.init(label: "Open Message", url: messageLink))]]
                )
            )
        }
    }

    func makeAuthorName(nick: String?, user: DiscordUser) -> String {
        let username = user.global_name ?? user.username
        if let nick, nick != username {
            return "\(username) (aka \(nick))"
        } else {
            return username
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
        isFailureMessage: Bool,
        userToExplicitlyMention: UserSnowflake? = nil
    ) async {
        await discordService.sendThanksResponse(
            channelId: channelId ?? event.channel_id,
            replyingToMessageId: event.id,
            isFailureMessage: isFailureMessage,
            userToExplicitlyMention: userToExplicitlyMention,
            response: response
        )
    }
}
