import DiscordBM
/// Import full foundation even on linux for `hash`, for now.
import Foundation
import Logging
import Models
import Shared

struct MessageHandler {
    let event: Gateway.MessageCreate
    let context: HandlerContext
    var logger = Logger(label: "MessageHandler")

    init(event: Gateway.MessageCreate, context: HandlerContext) {
        self.event = event
        self.context = context
        self.logger[metadataKey: "event"] = "\(event)"
    }

    func handle() async {
        let isBot = event.author?.bot == true

        /// Stop the bot from responding to other bots and itself
        if !isBot {
            await checkForNewCoins()
            await checkForAutoFaqs()
            await checkForPings()
            await checkForGuildSubscriptionCoins()
        }
        /// Check for bot messages like Penny's own messages too
        await publishAnnouncementMessages()
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
            excludedUsers: [author.id]  // Can't give yourself a coin
        )
        let usersWithNewCoins = coinHandler.findUsers()

        if usersWithNewCoins.isEmpty { return }

        var successfulResponses = [String]()
        successfulResponses.reserveCapacity(usersWithNewCoins.count)

        for receiver in usersWithNewCoins {
            let coinRequest = UserRequest.CoinEntryRequest(
                amount: 1,
                fromDiscordID: author.id,
                toDiscordID: receiver,
                source: .discord,
                reason: .userProvided
            )
            do {
                let response = try await context.usersService.postCoin(with: coinRequest)
                let responseString =
                    "\(DiscordUtils.mention(id: response.receiver)) now has \(response.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!"
                successfulResponses.append(responseString)
            } catch {
                logger.report(
                    "UsersService failed",
                    error: error,
                    metadata: [
                        "request": "\(coinRequest)"
                    ]
                )
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
                logger.warning(
                    "Can't send the full thanks-response",
                    metadata: [
                        "full": .string(finalResponse)
                    ]
                )
                await self.respondToThanks(
                    with: "Coins were granted to a lot of members!",
                    isFailureMessage: false
                )
            } else {
                await self.respondToThanks(with: finalResponse, isFailureMessage: false)
            }
        }
    }

    static let messageGuildSubscriptionTypes: Set<DiscordChannel.Message.Kind> = [
        .userPremiumGuildSubscription,
        .userPremiumGuildSubscriptionTier1,
        .userPremiumGuildSubscriptionTier2,
        .userPremiumGuildSubscriptionTier3,
    ]

    /// Like server boosts.
    func checkForGuildSubscriptionCoins() async {
        guard Self.messageGuildSubscriptionTypes.contains(event.type) else { return }

        guard let author = event.author else {
            logger.error("Cannot find author of the message")
            return
        }

        let amount = 10
        let coinRequest = UserRequest.CoinEntryRequest(
            amount: amount,
            /// Guild-id because it's not an actual user who gave the coins.
            fromDiscordID: UserSnowflake(Constants.vaporGuildId),
            toDiscordID: author.id,
            source: .discord,
            reason: .automationProvided
        )
        do {
            let response = try await context.usersService.postCoin(with: coinRequest)
            await self.respondToThanks(
                with: """
                    Thanks for the Server Boost \(Constants.ServerEmojis.love.emoji)!
                    You now have \(amount) more \(Constants.ServerEmojis.coin.emoji) for a total of \(response.newCoinCount) \(Constants.ServerEmojis.coin.emoji)!
                    """,
                overrideChannelId: Constants.Channels.thanks.id,
                isFailureMessage: false,
                userToExplicitlyMention: author.id
            )
        } catch {
            logger.report(
                "UsersService failed for server boost thanks",
                error: error,
                metadata: [
                    "request": "\(coinRequest)"
                ]
            )
            /// Don't send a message at all in case of failure
        }
    }

    func checkForAutoFaqs() async {
        guard let author = event.author else { return }

        let content = event.content
        if content.isEmpty { return }

        let autoFaqsDict: [String: String]
        do {
            autoFaqsDict = try await context.autoFaqsService.getAllFolded()
        } catch {
            logger.report("Can't retrieve auto-faqs", error: error)
            return
        }

        let foldedContent = content.superHeavyFolded()

        let matches = autoFaqsDict.filter({
            foldedContent.contains($0.key)
        }).map(\.value)

        for value in matches {
            guard
                await context.autoFaqsService.canRespond(
                    receiverID: author.id,
                    faqHash: value.hash
                )
            else { continue }
            await context.discordService.sendMessage(
                channelId: event.channel_id,
                payload: .init(
                    embeds: [
                        .init(
                            title: "🤖 Automated Answer",
                            description: value,
                            color: .blue
                        )
                    ],
                    message_reference: .init(
                        message_id: event.id,
                        channel_id: event.channel_id,
                        guild_id: event.guild_id,
                        fail_if_not_exists: true
                    )
                )
            )
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
            expUsersDict = try await context.pingsService.getAll().items
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
                    if (try? await context.discordService.userHasReadAccess(
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
        let mentionUsers = Set(event.mentions.map(\.id))
        /// For now we don't need to worry about Discord rate-limits,
        /// `DiscordBM` will do enough and will try to not exceed them.
        /// If at some point this starts to hit rate-limits,
        /// we can just wait 1-2s before sending each message.
        for (userId, words) in usersToPing {
            if mentionUsers.contains(userId) {
                /// User is already mentioned in the message, no need to ping them.
                continue
            }

            /// Identify if this could be a test message by the bot-dev.
            let mightBeATestMessage =
                userId == Constants.botDevUserId
                && event.channel_id == Constants.Channels.botLogs.id

            if !mightBeATestMessage {
                /// Don't `@` someone for their own message.
                if userId == author.id { continue }
            }
            let authorName = makeAuthorName(nick: member.nick, user: author)
            let iconURLEndpoint =
                member.avatar.map { avatar in
                    CDNEndpoint.guildMemberAvatar(
                        guildId: guildId,
                        userId: author.id,
                        avatar: avatar
                    )
                }
                ?? author.avatar.map { avatar in
                    CDNEndpoint.userAvatar(
                        userId: author.id,
                        avatar: avatar
                    )
                }
            await context.discordService.sendDM(
                userId: Snowflake(userId),
                payload: .init(
                    embeds: [
                        .init(
                            description: """
                                There is a new message in \(channelLink) that might be of interest to you.

                                Triggered by:
                                \(words.makeExpressionListForDiscord())

                                >>> \(content.unicodesPrefix(256))
                                """,
                            color: .blue,
                            footer: .init(
                                text: "By \(authorName)",
                                icon_url: (iconURLEndpoint?.url).map { .exact($0) }
                            )
                        )
                    ],
                    components: [[.button(.init(label: "Open Message", url: messageLink))]]
                )
            )
        }
    }

    func publishAnnouncementMessages() async {
        guard Constants.Channels.announcementChannels.contains(event.channel_id) else {
            logger.debug("Channel \(event.channel_id) is not an announcement channel")
            return
        }
        logger.debug("Publishing message \(event.id) that was sent in \(event.channel_id)")
        /// "Publish" the message to other announcement-channel subscribers
        await context.discordService.crosspostMessage(
            channelId: event.channel_id,
            messageId: event.id
        )
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
        await context.discordService.sendThanksResponse(
            channelId: channelId ?? event.channel_id,
            replyingToMessageId: event.id,
            isFailureMessage: isFailureMessage,
            content: userToExplicitlyMention.map(DiscordUtils.mention(id:)),
            response: response
        )
    }
}
