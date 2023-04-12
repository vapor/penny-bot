import DiscordBM
import Logging
import PennyModels

private enum Configuration {
    static let autoPingsMaxLimit = 100
    static let autoPingsLowLimit = 20
}

struct InteractionHandler {
    var logger = Logger(label: "InteractionHandler")
    let event: Interaction
    let coinService: any CoinService
    var pingsService: any AutoPingsService {
        ServiceFactory.makePingsService()
    }
    var discordService: DiscordService { .shared }
    
    private let oops = "Oopsie Woopsie... Something went wrong :("
    
    typealias InteractionOption = Interaction.ApplicationCommand.Option
    
    init(event: Interaction, coinService: any CoinService) {
        self.event = event
        self.logger[metadataKey: "event"] = "\(event)"
        self.coinService = coinService
    }
    
    func handle() async {
        switch event.data {
        case let .applicationCommand(data):
            guard let kind = CommandKind(name: data.name) else {
                logger.error("Unrecognized command")
                return await sendInteractionResolveFailure()
            }
            if kind.shouldSendAcknowledgment {
                guard await sendAcknowledgement(isEphemeral: kind.isEphemeral) else { return }
            }
            let response = await makeResponseForApplicationCommand(kind: kind, data: data)
            await respond(with: response, shouldEdit: kind.shouldSendAcknowledgment)
        case let .modalSubmit(modal):
            guard let modalId = ModalID(rawValue: modal.custom_id) else {
                logger.error("Unrecognized command")
                return await sendInteractionResolveFailure()
            }
            let response: any Response
            do {
                response = try await makeResponseForModal(modal: modal, modalId: modalId)
            } catch {
                logger.report("Failed to generate modal response", error: error)
                response = oops
            }
            await respond(with: response, shouldEdit: false, forceEphemeral: true)
        default:
            logger.error("Unrecognized command")
            return await sendInteractionResolveFailure()
        }
    }
}

/// MARK: - makeResponseForModal
private extension InteractionHandler {
    func makeResponseForModal(
        modal: Interaction.ModalSubmit,
        modalId: ModalID
    ) async throws -> any Response {
        guard let member = event.member else {
            logger.error("Discord did not send required info")
            return oops
        }
        guard let discordId = (event.member?.user ?? event.user)?.id else {
            logger.error("Can't find a user's id")
            return oops
        }
        switch modalId {
        case let .autoPings(autoPingsMode, mode):
            guard let component = modal.components.first?.components.first,
                  case let .textInput(textInput) = component,
                  let _text = textInput.value else {
                logger.error("Can't find the texts value")
                return oops
            }
            switch autoPingsMode {
            case .add:
                let allExpressions = _text.divideIntoAutoPingsExpressions(mode: mode)

                if allExpressions.isEmpty {
                    return "The list you sent seems to be empty."
                }

                let (existingExpressions, newExpressions) = try await allExpressions.divide {
                    try await pingsService.exists(expression: $0, forDiscordID: discordId)
                }

                let tooShorts = newExpressions.filter({ $0.innerValue.unicodeScalars.count < 3 })
                if !tooShorts.isEmpty {
                    return """
                    Some texts are less than 3 letters, which is not acceptable:
                    \(tooShorts.makeExpressionListForDiscord())
                    """
                }

                let current = try await pingsService.get(discordID: discordId)
                let limit = await discordService.memberHasRolesForElevatedPublicCommandsAccess(
                    member: member
                ) ? Configuration.autoPingsMaxLimit : Configuration.autoPingsLowLimit
                if newExpressions.count + current.count > limit {
                    return "You currently have \(current.count) expressions and you want to add \(newExpressions.count) more, but you have a limit of \(limit) expressions."
                }

                /// Still try to insert `allExpressions` just incase our data is out of sync
                try await pingsService.insert(allExpressions, forDiscordID: discordId)

                var components = [String]()

                if !newExpressions.isEmpty {
                    components.append(
                    """
                    Successfully added the followings to your pings-list:
                    \(newExpressions.makeExpressionListForDiscord())
                    """
                    )
                }

                if !existingExpressions.isEmpty {
                    components.append(
                        """
                        Some expressions were already available in your pings list:
                        \(existingExpressions.makeExpressionListForDiscord())
                        """
                    )
                }

                return components.joined(separator: "\n\n")
            case .remove:
                let allExpressions = _text.divideIntoAutoPingsExpressions(mode: mode)

                if allExpressions.isEmpty {
                    return "The list you sent seems to be empty."
                }

                let (existingExpressions, newExpressions) = try await allExpressions.divide {
                    try await pingsService.exists(expression: $0, forDiscordID: discordId)
                }

                /// Still try to remove `allExpressions` just incase our data is out of sync
                try await pingsService.remove(allExpressions, forDiscordID: discordId)

                var components = [String]()

                if !existingExpressions.isEmpty {
                    components.append(
                        """
                        Successfully removed the followings from your pings-list:
                        \(existingExpressions.makeExpressionListForDiscord())
                        """
                    )
                }

                if !newExpressions.isEmpty {
                    components.append(
                        """
                        Some expressions were not available in your pings list at all:
                        \(newExpressions.makeExpressionListForDiscord())
                        """
                    )
                }

                return components.joined(separator: "\n\n")
            }
        }
    }
}

/// MARK: - makeResponseForApplicationCommand
private extension InteractionHandler {
    func makeResponseForApplicationCommand(
        kind: CommandKind,
        data: Interaction.ApplicationCommand
    ) async -> any Response {
        let options = data.options ?? []
        switch kind {
        case .link:
            return handleLinkCommand(options: options)
        case .autoPings:
            do {
                return try await handlePingsCommand(options: options)
            } catch {
                logger.report("Pings command error", error: error)
                return oops
            }
        case .howManyCoins:
            return await handleHowManyCoinsCommand(
                author: event.member?.user ?? event.user,
                options: options
            )
        case .howManyCoinsApp:
            return await handleHowManyCoinsAppCommand()
        }
    }
    
    func handleLinkCommand(options: [InteractionOption]) -> String {
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
            return "This command is still a WIP. Linking Discord with Discord ID '\(id)'"
        case "github":
            return "This command is still a WIP. Linking Discord with Github ID '\(id)'"
        case "slack":
            return "This command is still a WIP. Linking Discord with Slack ID '\(id)'"
        default:
            logger.error("Unrecognized link option", metadata: ["name": "\(first.name)"])
            return oops
        }
    }
    
    func handlePingsCommand(options: [InteractionOption]) async throws -> any Response {
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
        switch subcommand {
        case .help:
            let allCommands = await discordService.getCommands()
            return makeAutoPingsHelp(commands: allCommands)
        case .add:
            guard let mode = self.requireExpressionModeOrReport(first.options) else {
                return oops
            }
            let modalId = ModalID.autoPings(.add, mode)
            return modalId.makeModal()
        case .remove:
            guard let mode = self.requireExpressionModeOrReport(first.options) else {
                return oops
            }
            let modalId = ModalID.autoPings(.remove, mode)
            return modalId.makeModal()
        case .list:
            let items = try await pingsService.get(discordID: discordId)
            if items.isEmpty {
                return "You have not set any expressions to be pinged for."
            } else {
                return """
                Your expressions:
                \(items.makeExpressionListForDiscord())
                """
            }
        case .test:
            guard let options = first.options,
                  !options.isEmpty,
                  let message = options.first(where: { $0.name == "message" })?.value?.asString
            else {
                logger.error("Discord did not send required info")
                return oops
            }
            guard let mode = self.requireExpressionModeOrReport(first.options) else {
                return oops
            }

            if let _text = options.first(where: { $0.name == "texts" })?.value?.asString {
                let dividedExpressions = _text.divideIntoAutoPingsExpressions(mode: mode)

                let divided = message.divideForPingCommandExactMatchChecking()
                let folded = message.foldedForPingCommandContainmentChecking()
                let triggeredExpressions = dividedExpressions.filter { exp in
                    MessageHandler.triggersPing(
                        dividedForExactMatchChecking: divided,
                        foldedForContainmentChecking: folded,
                        expression: exp
                    )
                }

                var response = """
                The message is:

                > \(message)

                And the entered texts are:

                > \(_text)


                """

                if dividedExpressions.isEmpty {
                    response += "The texts you entered seems like an empty list to me."
                } else {
                    response += """
                    The identified expressions are:
                    \(dividedExpressions.makeExpressionListForDiscord())


                    """
                    if triggeredExpressions.isEmpty {
                        response += "The message won't trigger any of the expressions above."
                    } else {
                        response += """
                        The message will trigger these expressions:
                        \(triggeredExpressions.makeExpressionListForDiscord())
                        """
                    }
                }

                return response
            } else {
                let currentExpressions = try await pingsService.get(discordID: discordId)

                let divided = message.divideForPingCommandExactMatchChecking()
                let folded = message.foldedForPingCommandContainmentChecking()
                let triggeredExpressions = currentExpressions.filter { exp in
                    MessageHandler.triggersPing(
                        dividedForExactMatchChecking: divided,
                        foldedForContainmentChecking: folded,
                        expression: exp
                    )
                }

                if currentExpressions.isEmpty {
                    return """
                    You pings-list is empty.
                    Either use the `texts` field, or add some expressions.
                    """
                } else {
                    var response = """
                    The message is:

                    > \(message)


                    """

                    if triggeredExpressions.isEmpty {
                        response += "The message won't trigger any of your expressions."
                    } else {
                        response += """
                        The message will trigger these ping expressions:
                        \(triggeredExpressions.makeExpressionListForDiscord())
                        """
                    }

                    return response
                }
            }
        }
    }
    
    func requireExpressionModeOrReport(_ options: [InteractionOption]?) -> ExpressionMode? {
        if let _mode = options?.first(where: { $0.name == "mode" })?.value?.asString {
            if let mode = ExpressionMode(rawValue: _mode) {
                return mode
            } else {
                logger.error("Discord sent invalid ExpressionMode", metadata: [
                    "invalid-mode": .string(_mode.debugDescription)
                ])
                return nil
            }
        } else {
            logger.error("Discord didn't send ExpressionMode")
            return nil
        }
    }
    
    func handleHowManyCoinsAppCommand() async -> String {
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
        options: [InteractionOption]
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
    private func sendAcknowledgement(isEphemeral: Bool) async -> Bool {
        await discordService.respondToInteraction(
            id: event.id,
            token: event.token,
            payload: .deferredChannelMessageWithSource(
                isEphemeral ? .init(flags: [.ephemeral]) : nil
            )
        )
    }
    
    private func sendInteractionResolveFailure() async {
        await discordService.respondToInteraction(
            id: event.id,
            token: event.token,
            payload: .channelMessageWithSource(.init(
                embeds: [.init(
                    description: "Failed to resolve the interaction :(",
                    color: .vaporPurple
                )],
                flags: [.ephemeral]
            ))
        )
    }
    
    private func respond(
        with response: any Response,
        shouldEdit: Bool,
        forceEphemeral: Bool = false
    ) async {
        if shouldEdit {
            /// Edits can't change the 'ephemeral' status of a message
            guard let data = response.makeResponse(isEphemeral: false).data else {
                logger.error("Can't edit a response with empty data", metadata: [
                    "response": "\(response)"
                ])
                return
            }
            await discordService.editInteraction(token: event.token, payload: data)
        } else {
            await discordService.respondToInteraction(
                id: event.id,
                token: event.token,
                payload: response.makeResponse(isEphemeral: forceEphemeral)
            )
        }
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

    var shouldSendAcknowledgment: Bool {
        switch self {
        case .autoPings: return false
        case .link, .howManyCoins, .howManyCoinsApp: return true
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

private enum ModalID: RawRepresentable {

    enum AutoPingsMode: String {
        case add, remove
    }

    case autoPings(AutoPingsMode, ExpressionMode)

    func makeModal() -> RequestBody.InteractionResponse.Modal {
        .init(
            custom_id: self.rawValue,
            title: self.title,
            components: [self.component]
        )
    }

    private var title: String {
        switch self {
        case let .autoPings(autoPingsMode, expressionMode):
            let autoPingsMode = autoPingsMode.rawValue.capitalized
            let expressionMode = expressionMode.rawValue
            return "\(autoPingsMode) with mode '\(expressionMode)'"
        }
    }

    private var component: Interaction.ActionRow {
        switch self {
        case let .autoPings(autoPingsMode, expressionMode):
            let autoPingsMode = autoPingsMode.rawValue.capitalized
            let expressionMode = expressionMode.rawValue
            return .init(components: [
                .textInput(.init(
                    custom_id: "texts",
                    style: .paragraph,
                    label: "\(autoPingsMode) Ping Texts with mode '\(expressionMode)'",
                    min_length: 3,
                    required: true,
                    placeholder: "Example: vapor, fluent, swift, websocket kit, your-name"
                ))
            ])
        }
    }

    var rawValue: String {
        switch self {
        case let .autoPings(autoPingsMode, expressionMode):
            return "auto-pings;\(autoPingsMode.rawValue);\(expressionMode.rawValue)"
        }
    }

    init? (rawValue: String) {
        let split = rawValue.split(separator: ";")
        if split.count == 3,
           split[0] == "auto-pings",
           let autoPingsMode = AutoPingsMode(rawValue: String(split[1])),
           let expressionMode = ExpressionMode(rawValue: String(split[2])) {
            self = .autoPings(autoPingsMode, expressionMode)
        } else {
            return nil
        }
    }
}

enum ExpressionMode: String, CaseIterable {
    case match
    case contain
    
    static let `default`: ExpressionMode = .match
}

private enum AutoPingsSubCommand: String, CaseIterable {
    case help
    case add
    case remove
    case list
    case test
}

private func makeAutoPingsHelp(commands: [ApplicationCommand]) -> String {
    
    let commandId = commands.first(where: { $0.name == "auto-pings" })?.id
    
    func command(_ subcommand: String) -> String {
        guard let id = commandId else {
            return "`/auto-pings \(subcommand)`"
        }
        return DiscordUtils.slashCommand(name: "auto-pings", id: id, subcommand: subcommand)
    }
    
    let isTypingEmoji = DiscordUtils.customAnimatedEmoji(
        name: "is_typing",
        id: "1087429908466253984"
    )
    
    return """
    **- Auto-Pings Help**
    
    You can add texts to be pinged for.
    When someone uses those texts, Penny will DM you about the message.
    
    - Penny can't DM you about messages in channels which Penny doesn't have access to (such as the role-related channels)
    
    > All auto-pings commands are ||private||, meaning they are visible to you and you only, and won't even trigger the \(isTypingEmoji) indicator.
    
    **Adding Expressions**
    
    You can add multiple texts using \(command("add")), separating the texts using commas (`,`). This command is Slack-compatible so you can copy-paste your Slack keywords to it.
    
    - Using 'mode' argument You can configure penny to look for exact matches or plain containment. Defaults to '\(ExpressionMode.default.rawValue)'.
    
    - All texts are **case-insensitive** (e.g. `a` == `A`), **diacritic-insensitive** (e.g. `a` == `á` == `ã`) and also **punctuation-insensitive**. Some examples of punctuations are: `\(#"“!?-_/\(){}"#)`.
    
    - All texts are **space-sensitive**.
    
    > Make sure Penny is able to DM you. You can enable direct messages for Vapor server members under your Server Settings.
    
    **Removing Expressions**
    
    You can remove multiple texts using \(command("remove")), separating the texts using commas (`,`).
    
    **Your Pings List**
    
    You can use \(command("list")) to see your current expressions.
    
    **Testing Expressions**
    
    You can use \(command("test")) to test if a message triggers some expressions.
    """
}

private extension String {
    func divideIntoAutoPingsExpressions(mode: ExpressionMode) -> [S3AutoPingItems.Expression] {
        self.split(whereSeparator: { $0 == "," || $0.isNewline })
            .map(String.init)
            .map({ $0.foldForPingCommand() })
            .filter({ !$0.isEmpty }).map {
                switch mode {
                case .match:
                    return S3AutoPingItems.Expression.match($0)
                case .contain:
                    return S3AutoPingItems.Expression.contain($0)
                }
            }
    }
}

/// MARK: - Response
private protocol Response {
    func makeResponse(isEphemeral: Bool) -> RequestBody.InteractionResponse
}

extension String: Response {
    func makeResponse(isEphemeral: Bool) -> RequestBody.InteractionResponse {
        .channelMessageWithSource(.init(embeds: [.init(
            description: self,
            color: .vaporPurple
        )], flags: isEphemeral ? [.ephemeral] : nil))
    }
}

extension RequestBody.InteractionResponse.Modal: Response {
    func makeResponse(isEphemeral _: Bool) -> RequestBody.InteractionResponse {
        .modal(self)
    }
}
