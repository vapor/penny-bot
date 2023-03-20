import DiscordBM
import Logging

private enum Configuration {
    static let autoPingsMaxLimit = 100
    static let autoPingsLowLimit = 10
}

struct InteractionHandler {
    var logger = Logger(label: "InteractionHandler")
    let event: Interaction
    let coinService: any CoinService
    var pingsService: any AutoPingsService {
        ServiceFactory.makePingsService()
    }
    var discordService: DiscordService { .shared }
    
    let oops = "Oopsie Woopsie... Something went wrong :("
    
    init(event: Interaction, coinService: any CoinService) {
        self.event = event
        self.logger[metadataKey: "event"] = "\(event)"
        self.coinService = coinService
    }
    
    func handle() async {
        guard case let .applicationCommand(data) = event.data,
              let kind = CommandKind(name: data.name) else {
            logger.error("Unrecognized command")
            return await sendInteractionNameResolveFailure()
        }
        guard await sendInteractionAcknowledgement(isEphemeral: kind.isEphemeral) else { return }
        let response = await processAndMakeResponse(kind: kind, data: data)
        await respond(with: response)
    }
    
    private func processAndMakeResponse(
        kind: CommandKind,
        data: Interaction.ApplicationCommand
    ) async -> String {
        let options = data.options ?? []
        switch kind {
        case .link: return handleLinkCommand(options: options)
        case .autoPings: return await handlePingsCommand(options: options)
        case .howManyCoins: return await handleHowManyCoinsCommand(
            author: event.member?.user ?? event.user,
            options: options
        )
        case .howManyCoinsApp: return await handleHowManyCoinsCommand()
        }
    }
    
    func handleLinkCommand(options: [Interaction.ApplicationCommand.Option]) -> String {
        if options.isEmpty {
            logger.error("Discord did not send required info")
            return oops
        }
        let first = options[0]
        guard let id = first.options?.first?.value?.asString else {
            logger.error("Discord did not send required info")
            return oops
        }
        switch first.name {
        case "discord":
            return "This command is still a WIP. Linking Discord with Discord ID \(id)"
        case "github":
            return "This command is still a WIP. Linking Discord with Github ID \(id)"
        case "slack":
            return "This command is still a WIP. Linking Discord with Slack ID \(id)"
        default:
            logger.error("Unrecognized link option", metadata: ["name": "\(first.name)"])
            return oops
        }
    }
    
    func handlePingsCommand(options: [Interaction.ApplicationCommand.Option]) async -> String {
        guard let member = event.member else {
            logger.error("Discord did not send required info")
            return oops
        }
        guard let discordId = (event.member?.user ?? event.user)?.id else {
            logger.error("Can't find a user's id")
            return oops
        }
        guard let first = options.first else {
            logger.error("Discord did not send required interaction info")
            return oops
        }
        guard let subcommand = AutoPingsSubCommand(rawValue: first.name) else {
            logger.error("Unrecognized 'auto-pings' command", metadata: ["name": "\(first.name)"])
            return oops
        }
        do {
            switch subcommand {
            case .help:
                let allCommands = await discordService.getCommands()
                return makeAutoPingsHelp(commands: allCommands)
            case .add:
                guard let option = first.options?.first,
                      let _text = option.value?.asString else {
                    logger.error("Discord did not send required info")
                    return oops
                }
                let allTexts = _text.divideIntoAutoPingsTexts()
                
                if allTexts.isEmpty {
                    return "The list you sent seems to be empty."
                }
                
                let (existingTexts, newTexts) = try await allTexts.divide {
                    try await pingsService.exists(text: $0, forDiscordID: discordId)
                }
                
                let tooShorts = newTexts.filter({ $0.unicodeScalars.count < 3 })
                if !tooShorts.isEmpty {
                    return """
                    Some texts are less than 3 letters, which is not acceptable:
                    \(tooShorts.makeEnumeratedListForDiscord())
                    """
                }
                
                let current = try await pingsService.get(discordID: discordId)
                let limit = await discordService.memberHasRolesForElevatedPublicCommandsAccess(
                    member: member
                ) ? Configuration.autoPingsMaxLimit : Configuration.autoPingsLowLimit
                if newTexts.count + current.count > limit {
                    return "You currently have \(current.count) texts and you want to add \(newTexts.count) more, but you have a limit of \(limit) texts."
                }
                
                /// Still try to insert `allTexts` just incase our data is out of sync
                try await pingsService.insert(allTexts, forDiscordID: discordId)
                
                var components = [String]()
                
                if !newTexts.isEmpty {
                    components.append(
                        """
                        Successfully added the followings to your pings-list:
                        \(newTexts.makeSortedEnumeratedListForDiscord())
                        """
                    )
                }
                
                if !existingTexts.isEmpty {
                    components.append(
                        """
                        Some texts were already available in your pings list:
                        \(existingTexts.makeSortedEnumeratedListForDiscord())
                        """
                    )
                }
                
                return components.joined(separator: "\n\n")
            case .remove:
                guard let option = first.options?.first,
                      let _text = option.value?.asString else {
                    logger.error("Discord did not send required info")
                    return oops
                }
                let allTexts = _text.divideIntoAutoPingsTexts()
                
                if allTexts.isEmpty {
                    return "The list you sent seems to be empty."
                }
                
                let (existingTexts, newTexts) = try await allTexts.divide {
                    try await pingsService.exists(text: $0, forDiscordID: discordId)
                }
                
                /// Still try to remove `allTexts` incase out data is out of sync
                try await pingsService.remove(allTexts, forDiscordID: discordId)
                
                var components = [String]()
                
                if !existingTexts.isEmpty {
                    components.append(
                        """
                        Successfully removed the followings from your pings-list:
                        \(existingTexts.makeSortedEnumeratedListForDiscord())
                        """
                    )
                }
                
                if !newTexts.isEmpty {
                    components.append(
                        """
                        Some texts were not available in your pings list at all:
                        \(newTexts.makeSortedEnumeratedListForDiscord())
                        """
                    )
                }
                
                return components.joined(separator: "\n\n")
            case .list:
                let items = try await pingsService
                    .get(discordID: discordId)
                    .map(\.innerValue)
                if items.isEmpty {
                    return "You have not set any texts to be pinged for."
                } else {
                    return """
                    Your ping texts:
                    \(items.makeSortedEnumeratedListForDiscord())
                    """
                }
            case .test:
                guard let options = first.options,
                      options.count > 0,
                      let _message = options.first(where: { $0.name == "message" }),
                      let message = _message.value?.asString else {
                    logger.error("Discord did not send required info")
                    return oops
                }
                
                if let _text = options.first(where: { $0.name == "texts" })?.value?.asString {
                    let divided = message.divideForPingCommandChecking()
                    let dividedTexts = _text.divideIntoAutoPingsTexts()
                    let triggeredTexts = dividedTexts.filter {
                        MessageHandler.textTriggersPing(dividedForPingCommand: divided, pingText: $0)
                    }
                    
                    var response = """
                    The message is:
                    
                    > \(message)
                    
                    And the entered texts are:
                    
                    > \(_text)
                    
                    
                    """
                    
                    if dividedTexts.isEmpty {
                        response += "The texts you entered seems like an empty list to me."
                    } else {
                        response += """
                        The identified texts are:
                        \(dividedTexts.makeSortedEnumeratedListForDiscord())
                        
                        
                        """
                        if triggeredTexts.isEmpty {
                            response += "The message won't trigger any of the texts above."
                        } else {
                            response += """
                            The message will trigger these texts:
                            \(triggeredTexts.makeSortedEnumeratedListForDiscord())
                            """
                        }
                    }
                    
                    return response
                } else {
                    let currentTexts = try await pingsService
                        .get(discordID: discordId)
                        .map(\.innerValue)
                    
                    let divided = message.divideForPingCommandChecking()
                    let triggeredTexts = currentTexts.filter {
                        MessageHandler.textTriggersPing(dividedForPingCommand: divided, pingText: $0)
                    }
                    
                    if currentTexts.isEmpty {
                        return """
                        You pings-list is empty.
                        Either use the `texts` field, or add some ping-texts.
                        """
                    } else {
                        var response = """
                        The message is:
                        
                        > \(message)
                        
                        
                        """
                        
                        if triggeredTexts.isEmpty {
                            response += "The message won't trigger any of your ping-texts."
                        } else {
                            response += """
                            The message will trigger these ping-texts:
                            \(triggeredTexts.makeSortedEnumeratedListForDiscord())
                            """
                        }
                        
                        return response
                    }
                }
            }
        } catch {
            logger.report("Pings command error", error: error)
            return oops
        }
    }
    
    func handleHowManyCoinsCommand() async -> String {
        guard case let .applicationCommand(data) = event.data,
              let userId = data.target_id else {
            logger.error("Coin-count command could not find appropriate data")
            return oops
        }
        let user = "<@\(userId)>"
        return await getCoinCount(of: user)
    }
    
    func handleHowManyCoinsCommand(
        author: DiscordUser?,
        options: [Interaction.ApplicationCommand.Option]
    ) async -> String {
        let user: String
        if let userOption = options.first?.value?.asString {
            user = "<@\(userOption)>"
        } else {
            guard let id = author?.id else {
                logger.error("Coin-count command could not find a user")
                return oops
            }
            user = "<@\(id)>"
        }
        return await getCoinCount(of: user)
    }
    
    func getCoinCount(of user: String) async -> String {
        do {
            let coinCount = try await coinService.getCoinCount(of: user)
            return "\(user) has \(coinCount) \(Constants.vaporCoinEmoji)!"
        } catch {
            logger.report("Coin-count command couldn't get coin count", error: error, metadata: [
                "user": "\(user)"
            ])
            return oops
        }
    }
    
    /// Returns `true` if the acknowledgement was successfully sent
    private func sendInteractionAcknowledgement(isEphemeral: Bool) async -> Bool {
        await discordService.respondToInteraction(
            id: event.id,
            token: event.token,
            payload: .init(
                type: .deferredChannelMessageWithSource,
                data: isEphemeral ? .init(flags: [.ephemeral]) : nil
            )
        )
    }
    
    private func sendInteractionNameResolveFailure() async {
        await discordService.respondToInteraction(
            id: event.id,
            token: event.token,
            payload: .init(
                type: .channelMessageWithSource,
                data: .init(embeds: [.init(
                    description: "Failed to resolve the interaction name :(",
                    color: .vaporPurple
                )], flags: [.ephemeral])
            )
        )
    }
    
    private func respond(with response: String) async {
        await discordService.editInteraction(
            token: event.token,
            payload: .init(embeds: [.init(
                description: response,
                color: .vaporPurple
            )])
        )
    }
}

private enum CommandKind {
    case link
    case autoPings
    case howManyCoins
    case howManyCoinsApp
    
    /// Ephemeral means the interaction will only be visible to the user, not the whole guild.
    var isEphemeral: Bool {
        switch self {
        case .link, .autoPings: return true
        case .howManyCoins, .howManyCoinsApp: return false
        }
    }
    
    init? (name: String) {
        switch name {
        case "link": self = .link
        case "auto-pings": self = .autoPings
        case "how-many-coins": self = .howManyCoins
        case "How Many Coins?": self = .howManyCoinsApp
        default: return nil
        }
    }
}

private func escapeCharacters(_ text: String) -> String {
    DiscordUtils.escapingSpecialCharacters(text, forChannelType: .text)
}

private enum AutoPingsSubCommand: String, CaseIterable {
    case help
    case add
    case remove
    case list
    case test
}

private func makeAutoPingsHelp(commands: [ApplicationCommand]) -> String {
    func makeCommandLink(_ subcommand: String) -> String {
        guard let id = commands.first(where: { $0.name == "auto-pings" })?.id else {
            return "`/auto-pings \(subcommand)`"
        }
        return DiscordUtils.slashCommand(name: "auto-pings", id: id, subcommand: subcommand)
    }
    
    return """
    **- Auto-Pings Help**
    
    You can add texts to be pinged for.
    When someone uses those texts, Penny will DM you about the message.
    
    - Penny can't DM you about messages in channels which Penny doesn't have access to (such as the role-related channels)
    
    - The command has a limit of \(Configuration.autoPingsLowLimit) ping-texts for members that have none of the following roles: \(rolesString)
    
    > All auto-pings commands are "private", meaning they are visible to you and you only, and won't even trigger the "is typing" indicator.
    
    **Adding Texts**
    
    You can add multiple texts using \(makeCommandLink("add")), separating the texts using commas (`,`). This command is Slack-compatible so you can copy-paste your Slack keywords to it.
    
    - Penny looks for **exact matches**, but all texts are **case-insensitive**, **diacritic-insensitive** and also **punctuation-insensitive**. Some examples of punctuations are: `\(#"“!?-_/\(){}"#)`
    
    > Make sure Penny is able to DM you. You can enable direct messages for Vapor server members under your Server Settings.
    
    **Removing Texts**
    
    You can remove multiple texts using \(makeCommandLink("remove")), separating the texts using commas (`,`).
    
    **Your Pings List**
    
    You can use \(makeCommandLink("list")) to see your current ping texts.
    
    **Testing Ping-Texts**
    
    You can use \(makeCommandLink("test")) to test if a message triggers some ping texts.
    """
}

private let rolesString = Constants.Roles
    .elevatedPublicCommandsAccess
    .map(\.rawValue)
    .map(DiscordUtils.roleMention(id:))
    .joined(separator: " ")

private extension String {
    func divideIntoAutoPingsTexts() -> [String] {
        self.split(separator: ",")
            .map(String.init)
            .map({ $0.foldForPingCommand() })
            .filter({ !$0.isEmpty })
    }
}
