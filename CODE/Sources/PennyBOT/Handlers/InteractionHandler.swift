import DiscordBM
import Logging

struct InteractionHandler {
    var logger = Logger(label: "InteractionHandler")
    let event: Interaction
    let coinService: any CoinService
    var pingsService: any AutoPingsService {
        ServiceFactory.makePingsService()
    }
    
    let oops = "Oopsie Woopsie... Something went wrong :("
    
    init(event: Interaction, coinService: any CoinService) {
        self.event = event
        self.logger[metadataKey: "event"] = "\(event)"
        self.coinService = coinService
    }
    
    func handle() async {
        guard case let .applicationCommand(data) = event.data,
              let kind = SlashCommandKind(name: data.name) else {
            logger.error("Unrecognized command")
            return await sendInteractionNameResolveFailure()
        }
        guard await sendInteractionAcknowledgement(isEphemeral: kind.isEphemeral) else { return }
        let response = await processAndMakeResponse(kind: kind, data: data)
        await respond(with: response)
    }
    
    private func processAndMakeResponse(
        kind: SlashCommandKind,
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
            return "Please provide more options"
        }
        let first = options[0]
        guard let id = first.options?.first?.value?.asString else {
            logger.error("Discord did not send required info")
            return "No ID option recognized"
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
            return "Option not recognized: \(first.name)"
        }
    }
    
    func handlePingsCommand(options: [Interaction.ApplicationCommand.Option]) async -> String {
        guard let member = event.member else {
            logger.error("Discord did not send required info")
            return "Sorry something went wrong :("
        }
        guard let discordId = (event.member?.user ?? event.user)?.id else {
            logger.error("Can't find a user's id")
            return "Sorry something went wrong :("
        }
        guard let first = options.first else {
            logger.error("Discord did not send required interaction info")
            return "Please provide more options"
        }
        guard let subcommand = AutoPingsSubCommand(rawValue: first.name) else {
            logger.error("Unrecognized 'auto-pings' command", metadata: ["name": "\(first.name)"])
            return "Option not recognized: \(first.name)"
        }
        if subcommand.requiresTechnicalRoles,
           await !DiscordService.shared.memberHasAnyTechnicalRoles(member: member) {
            logger.trace("Someone tried to use 'auto-pings' but they don't have any of the required roles")
            return "Sorry, to make sure Penny can handle the load, this functionality is currently restricted to members with any of these roles: \(rolesString)"
        }
        do {
            switch subcommand {
            case .help:
                let allCommands = await DiscordService.shared.getSlashCommands()
                return makeAutoPingsHelp(commands: allCommands)
            case .add:
                guard let option = first.options?.first,
                      let _text = option.value?.asString else {
                    logger.error("Discord did not send required info")
                    return "No 'texts' option recognized"
                }
                let allTexts = _text.split(separator: ",")
                    .map(String.init)
                    .map({ $0.foldForPingCommand() })
                    .filter({ !$0.isEmpty })
                
                if allTexts.isEmpty {
                    return "The list you sent seems to be empty"
                }
                
                let (existingTexts, newTexts) = try await allTexts.divide {
                    try await pingsService.exists(text: $0, forDiscordID: discordId)
                }
                
                if let first = newTexts.first(where: { $0.unicodeScalars.count < 3 }) {
                    let escaped = escapeCharacters(first)
                    return "A text is less than 3 letters: \(escaped)\n This is not acceptable"
                }
                
                let current = try await pingsService.get(discordID: discordId)
                if newTexts.count + current.count > 50 {
                    return "You can't have more than 50 ping texts"
                }
                
                /// Still try to insert `allTexts` just incase our data is out of sync
                try await pingsService.insert(allTexts, forDiscordID: discordId)
                
                var components = [String]()
                
                if !newTexts.isEmpty {
                    components.append(
                        """
                        Successfully added the followings to your pings-list:
                        \(newTexts.makeAutoPingsTextsList())
                        """
                    )
                }
                
                if !existingTexts.isEmpty {
                    components.append(
                        """
                        Some texts were already available in your pings list:
                        \(existingTexts.makeAutoPingsTextsList())
                        """
                    )
                }
                
                return components.joined(separator: "\n\n")
            case .remove:
                guard let option = first.options?.first,
                      let _text = option.value?.asString else {
                    logger.error("Discord did not send required info")
                    return "No 'texts' option recognized"
                }
                let allTexts = _text.split(separator: ",")
                    .map(String.init)
                    .map({ $0.foldForPingCommand() })
                    .filter({ !$0.isEmpty })
                
                if allTexts.isEmpty {
                    return "The list you sent seems to be empty"
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
                        \(existingTexts.makeAutoPingsTextsList())
                        """
                    )
                }
                
                if !newTexts.isEmpty {
                    components.append(
                        """
                        Some texts were not available in your pings list at all:
                        \(newTexts.makeAutoPingsTextsList())
                        """
                    )
                }
                
                return components.joined(separator: "\n\n")
            case .list:
                let items = try await pingsService
                    .get(discordID: discordId)
                    .map(\.innerValue)
                if items.isEmpty {
                    return "You have not set any texts to be pinged for"
                } else {
                    return """
                    Your ping texts:
                    \(items.makeAutoPingsTextsList())
                    """
                }
            }
        } catch {
            logger.report("Pings command error", error: error)
            return "Sorry, some errors happened :( Please try again"
        }
    }
    
    func handleHowManyCoinsCommand() async -> String {
        guard case let .applicationCommand(data) = event.data,
              let userId = data.target_id else {
            logger.error("Coin-count command could not find appropriate data")
            return oops
        }
        let user = "<@\(userId)>"
        do {
            let coinCount = try await coinService.getCoinCount(of: user)
            return "\(user) has \(coinCount) \(Constants.vaporCoinEmoji)"
        } catch {
            logger.report("Coin-count command couldn't get coin count", error: error, metadata: [
                "user": "\(user)"
            ])
            return oops
        }
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
        do {
            let coinCount = try await coinService.getCoinCount(of: user)
            return "\(user) has \(coinCount) \(Constants.vaporCoinEmoji)"
        } catch {
            logger.report("Coin-count command couldn't get coin count", error: error, metadata: [
                "user": "\(user)"
            ])
            return oops
        }
    }
    
    /// Returns `true` if the acknowledgement was successfully sent
    private func sendInteractionAcknowledgement(isEphemeral: Bool) async -> Bool {
        await DiscordService.shared.respondToInteraction(
            id: event.id,
            token: event.token,
            payload: .init(
                type: .deferredChannelMessageWithSource,
                data: isEphemeral ? .init(flags: [.ephemeral]) : nil
            )
        )
    }
    
    private func sendInteractionNameResolveFailure() async {
        await DiscordService.shared.respondToInteraction(
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
        await DiscordService.shared.editInteraction(
            token: event.token,
            payload: .init(embeds: [.init(
                description: response,
                color: .vaporPurple
            )])
        )
    }
}

private enum SlashCommandKind {
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
    
    var requiresTechnicalRoles: Bool {
        switch self {
        case .help: return false
        case .add, .remove, .list: return true
        }
    }
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
    
    - The auto-ping commands are currently restricted to users with any of these roles: \(rolesString)
    
    > All auto-pings commands are "private", meaning they are visible to you and you only, and won't even trigger the "is typing" indicator.
    
    **Adding Texts**
    
    You can add multiple texts using \(makeCommandLink("add")), separating the texts using commas (`,`). This command is Slack-compatible so you can copy-paste your Slack keywords to it.
    
    - Penny looks for **exact matches**, but all texts are **case-insensitive**, **diacritic-insensitive** and also **punctuation-insensitive**. Some examples of punctuations are: `\(#"“!?-_/\(){}"#)`
    
    > Make sure Penny is able to DM you. You can enable direct messages for Vapor server members under your Server Settings.
    
    **Removing Texts**
    
    You can remove multiple texts using \(makeCommandLink("remove")), separating the texts using commas (`,`).
    
    **Your Pings List**
    
    You can use \(makeCommandLink("list")) to see your current ping texts.
    """
}

private let rolesString = Constants.Roles
    .autoPingsAllowed
    .map(\.rawValue)
    .map(DiscordUtils.roleMention(id:))
    .joined(separator: " ")
