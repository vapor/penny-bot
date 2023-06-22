import DiscordBM
import Logging
import PennyModels

private enum Configuration {
    static let autoPingsMaxLimit = 100
    static let autoPingsLowLimit = 20
}

private typealias Expression = S3AutoPingItems.Expression

struct InteractionHandler {
    let event: Interaction
    var logger = Logger(label: "InteractionHandler")
    var coinService: any CoinService {
        ServiceFactory.makeCoinService()
    }
    var pingsService: any AutoPingsService {
        ServiceFactory.makePingsService()
    }
    var helpsService: any HelpsService {
        ServiceFactory.makeHelpsService()
    }
    var discordService: DiscordService { .shared }
    
    private let oops = "Oopsie Woopsie... Something went wrong :("
    
    typealias InteractionOption = Interaction.ApplicationCommand.Option
    
    init(event: Interaction) {
        self.event = event
        self.logger[metadataKey: "event"] = "\(event)"
    }
    
    func handle() async {
        switch event.data {
        case let .applicationCommand(data) where event.type == .applicationCommand:
            guard let command = SlashCommand(rawValue: data.name) else {
                logger.error("Unrecognized command")
                return await sendInteractionResolveFailure()
            }
            if command.shouldSendAcknowledgment {
                guard await sendAcknowledgement(isEphemeral: command.isEphemeral) else { return }
            }
            if let response = await makeResponseForApplicationCommand(
                command: command,
                data: data
            ) {
                await respond(with: response, shouldEdit: true)
            }
        case let .applicationCommand(data) where event.type == .applicationCommandAutocomplete:
            guard let command = SlashCommand(rawValue: data.name) else {
                logger.error("Unrecognized command")
                return await sendInteractionResolveFailure()
            }
            guard command == .help else {
                logger.error("Unrecognized autocomplete command")
                return await sendInteractionResolveFailure()
            }
            let options = data.options ?? []
            let response: any Response
            do {
                response = try await handleHelpCommandAutocomplete(options: options)
            } catch {
                logger.report("Help command error", error: error)
                response = self.oops
            }
            await respond(with: response, shouldEdit: false)
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

// MARK: - makeResponseForModal
private extension InteractionHandler {
    func makeResponseForModal(
        modal: Interaction.ModalSubmit,
        modalId: ModalID
    ) async throws -> any Response {
        let member = try event.member.requireValue()
        let discordId = try (event.member?.user ?? event.user).requireValue().id
        switch modalId {
        case let .autoPings(autoPingsMode, mode):
            switch autoPingsMode {
            case .add:
                let allExpressions = try modal.components
                    .requireComponent(customId: "texts")
                    .requireTextInput()
                    .value.requireValue()
                    .divideIntoAutoPingsExpressions(mode: mode)

                if allExpressions.isEmpty {
                    return "The list you sent seems to be empty."
                }

                let (existingExpressions, newExpressions) = try await allExpressions.divided {
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
                    logger.error("Someone hit their expressions count limit", metadata: [
                        "limit": .stringConvertible(limit),
                        "current": .stringConvertible(current),
                        "new": .stringConvertible(newExpressions),
                    ])
                    return "You currently have \(current.count) expressions and you want to add \(newExpressions.count) more, but you have a limit of \(limit) expressions."
                }

                discardingResult {
                    /// Always try to insert `allExpressions` just incase our data is out of sync
                    try await pingsService.insert(allExpressions, forDiscordID: discordId)
                }

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
                let allExpressions = try modal.components
                    .requireComponent(customId: "texts")
                    .requireTextInput()
                    .value.requireValue()
                    .divideIntoAutoPingsExpressions(mode: mode)

                if allExpressions.isEmpty {
                    return "The list you sent seems to be empty."
                }

                let (existingExpressions, newExpressions) = try await allExpressions.divided {
                    try await pingsService.exists(expression: $0, forDiscordID: discordId)
                }

                discardingResult {
                    /// Always try to remove `allExpressions` just incase our data is out of sync
                    try await pingsService.remove(allExpressions, forDiscordID: discordId)
                }

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
                        Some expressions were not available in your pings list at all with '\(mode.UIDescription)' mode:
                        \(newExpressions.makeExpressionListForDiscord())
                        """
                    )
                }

                return components.joined(separator: "\n\n")
            case .test:
                let message = try modal.components
                    .requireComponent(customId: "message")
                    .requireTextInput()
                    .value.requireValue()
                let textInput = try modal.components
                    .requireComponent(customId: "texts")
                    .requireTextInput()

                if let _text = textInput.value?.trimmingCharacters(in: .whitespaces),
                    !_text.isEmpty {
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
                        response += "The texts you entered seem like an empty list to me."
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
        case let .help(helpMode):
            switch helpMode {
            case .add:
                let name = try modal.components
                    .requireComponent(customId: "name")
                    .requireTextInput()
                    .value.requireValue()
                let newValue = try modal.components
                    .requireComponent(customId: "value")
                    .requireTextInput()
                    .value.requireValue()

                if name.contains("\n") {
                    let nameNoNewLines = name.replacingOccurrences(of: "\n", with: " ")
                    return """
                    The name cannot contain new lines. You can try '\(nameNoNewLines)' instead.

                    New value:
                    > \(newValue)
                    """
                }

                if let value = try await helpsService.get(name: name) {
                    return """
                    A help-text with name '\(name)' already exists. Please remove it first.

                    New value:
                    > \(newValue)

                    Old value:
                    > \(value)
                    """
                }

                if name.isEmpty || newValue.isEmpty {
                    return "'name' or 'value' seem empty to me :("
                }
                /// The response of this command is ephemeral so members feel free to add help-texts.
                /// We will log this action so we can know if something malicious is happening.
                logger.notice("Will add a help-text", metadata: [
                    "name": .string(name),
                    "value": .string(newValue),
                ])
                try await helpsService.insert(name: name, value: newValue)
                return """
                Added a new help-text with name '\(name)':

                > \(newValue)
                """
            }
        }
    }

    /// Used to not care about result of auto-pings mutations.
    /// This is because Discord expects us to answer in 3 seconds,
    /// and waiting for auto-pings lambda makes us too slow.
    private func discardingResult(
        _ operation: @escaping () async throws -> Void,
        function: String = #function,
        line: UInt = #line
    ) {
        Task {
            do {
                try await operation()
            } catch {
                logger.report("Pings Service failed", error: error, function: function, line: line)
            }
        }
    }
}

// MARK: - makeResponseForApplicationCommand
private extension InteractionHandler {
    /// Returns `nil` if no response is supposed to be sent to user.
    func makeResponseForApplicationCommand(
        command: SlashCommand,
        data: Interaction.ApplicationCommand
    ) async -> (any Response)? {
        let options = data.options ?? []
        do {
            switch command {
            case .link:
                return try handleLinkCommand(options: options)
            case .autoPings:
                return try await handlePingsCommand(options: options)
            case .help:
                return try await handleHelpCommand(options: options)
            case .howManyCoins:
                return try await handleHowManyCoinsCommand(
                    author: event.member?.user ?? event.user,
                    options: options
                )
            case .howManyCoinsApp:
                return try await handleHowManyCoinsAppCommand()
            }
        } catch {
            logger.report("Command error", error: error)
            return oops
        }
    }
    
    func handleLinkCommand(options: [InteractionOption]) throws -> String {
        let first = try options.first.requireValue()
        let subCommand = try LinkSubCommand(rawValue: first.name).requireValue()
        let id = try (first.options?.first).requireValue().requireString()
        switch subCommand {
        case .discord:
            return "This command is still a WIP. Linking Discord with Discord ID '\(id)'"
        case .github:
            return "This command is still a WIP. Linking Discord with Github ID '\(id)'"
        case .slack:
            return "This command is still a WIP. Linking Discord with Slack ID '\(id)'"
        }
    }
    
    func handlePingsCommand(options: [InteractionOption]) async throws -> (any Response)? {
        let discordId = try (event.member?.user ?? event.user).requireValue().id
        let first = try options.first.requireValue()
        let subcommand = try AutoPingsSubCommand(rawValue: first.name).requireValue()

        switch subcommand {
        case .help, .list:
            guard await sendAcknowledgement(isEphemeral: true) else { return nil }
        case .add, .remove, .test:
            /// Response of these commands are modals.
            /// For modals you can't send an acknowledgement first, then send the modal.
            /// You have to just right-away send the modal.
            break
        }

        switch subcommand {
        case .help:
            let allCommands = await discordService.getCommands()
            return makeAutoPingsHelp(commands: allCommands)
        case .list:
            let items = try await pingsService.get(discordID: discordId)
            if items.isEmpty {
                return "You have not set any expressions to be pinged for."
            } else {
                return """
                Your expressions
                \(items.makeExpressionListForDiscord())
                """
            }
        case .add:
            let mode = try self.requireExpressionMode(first.options)
            let modalId = ModalID.autoPings(.add, mode)
            return modalId.makeModal()
        case .remove:
            let mode = try self.requireExpressionMode(first.options)
            let modalId = ModalID.autoPings(.remove, mode)
            return modalId.makeModal()
        case .test:
            let mode = try self.requireExpressionMode(first.options)
            let modalId = ModalID.autoPings(.test, mode)
            return modalId.makeModal()
        }
    }

    func handleHelpCommand(options: [InteractionOption]) async throws -> (any Response)? {
        let first = try options.first.requireValue()
        let subcommand = try HelpSubCommand(rawValue: first.name).requireValue()
        switch subcommand {
        case .get:
            guard await sendAcknowledgement(isEphemeral: false) else { return nil }
        case .remove:
            /// This is ephemeral so members feel free to remove stuff,
            /// but we will log this action so we can know if something malicious is happening.
            guard await sendAcknowledgement(isEphemeral: true) else { return nil }
        case .add:
            /// Uses modals so can't send an acknowledgment first.
            break
        }
        switch subcommand {
        case .get:
            let name = try first.options
                .requireValue()
                .requireOption(named: "name")
                .requireString()
            if let value = try await helpsService.get(name: name) {
                return value
            } else {
                return "No help-text with name '\(name)' exists at all"
            }
        case .remove:
            let name = try first.options
                .requireValue()
                .requireOption(named: "name")
                .requireString()
            let member = try event.member.requireValue()
            guard await discordService.memberHasRolesForElevatedRestrictedCommandsAccess(
                member: member
            ) else {
                let rolesString = Constants.Roles
                    .elevatedRestrictedCommandsAccess
                    .map(\.rawValue)
                    .map(DiscordUtils.mention(id:))
                    .joined(separator: " ")
                return "You don't have access to this command; it is only available to \(rolesString)"
            }
            guard let value = try await helpsService.get(name: name) else {
                return "No help-text with name '\(name)' exists at all"
            }
            logger.warning("Will remove a help-text", metadata: [
                "name": .string(name),
                "value": .string(value),
            ])
            try await helpsService.remove(name: name)
            return "Removed a help-text with name '\(name)'"
        case .add:
            guard let member = event.member else {
                logger.error("Discord did not send required info")
                return oops
            }
            guard await discordService.memberHasRolesForElevatedRestrictedCommandsAccess(
                member: member
            ) else {
                /// To not make things too complicated for now, send an acknowledgment,
                /// so the String we return can be sent as an "edit".
                guard await sendAcknowledgement(isEphemeral: true) else { return nil }
                let rolesString = Constants.Roles
                    .elevatedRestrictedCommandsAccess
                    .map(\.rawValue)
                    .map(DiscordUtils.mention(id:))
                    .joined(separator: " ")
                return "You don't have access to this command; it is only available to \(rolesString)"
            }
            let modalId = ModalID.help(.add)
            return modalId.makeModal()
        }
    }

    func handleHelpCommandAutocomplete(options: [InteractionOption]) async throws -> any Response {
        let first = try options.first.requireValue()
        let subcommand = try HelpSubCommand(rawValue: first.name).requireValue()
        guard [.get, .remove].contains(subcommand) else {
            logger.error(
                "Unrecognized 'help' subcommand for autocomplete",
                metadata: ["subcommand": "\(subcommand)"]
            )
            return oops
        }
        let name = try first.options
            .requireValue()
            .requireOption(named: "name")
            .requireString()
        let foldedName = name.heavyFolded()
        return try await Payloads.InteractionResponse.Autocomplete(
            choices: helpsService
                .getAll()
                .filter { $0.key.heavyFolded().contains(foldedName) }
                .sorted { $0.key < $1.key }
                .prefix(25)
                .map { .init(name: $0.key, value: .string($0.value)) }
        )
    }
    
    func requireExpressionMode(_ options: [InteractionOption]?) throws -> Expression.Kind {
        let optionValue = try options.requireValue().requireOption(named: "mode").requireString()
        return try Expression.Kind(rawValue: optionValue).requireValue()
    }
    
    func handleHowManyCoinsAppCommand() async throws -> String {
        guard case let .applicationCommand(data) = event.data,
              let userId = data.target_id else {
            logger.error("Coin-count command could not find appropriate data")
            return oops
        }
        let user = "<@\(userId.rawValue)>"
        return try await getCoinCount(of: user)
    }
    
    func handleHowManyCoinsCommand(
        author: DiscordUser?,
        options: [InteractionOption]
    ) async throws -> String {
        let user: String
        if let userOption = options.first?.value?.asString {
            user = "<@\(userOption)>"
        } else {
            guard let id = author?.id else {
                logger.error("Coin-count command could not find a user")
                return oops
            }
            user = "<@\(id.rawValue)>"
        }
        return try await getCoinCount(of: user)
    }
    
    func getCoinCount(of user: String) async throws -> String {
        let coinCount = try await coinService.getCoinCount(of: user)
        return "\(user) has \(coinCount) \(Constants.ServerEmojis.coin.emoji)!"
    }
    
    /// Returns `true` if the acknowledgement was successfully sent
    private func sendAcknowledgement(isEphemeral: Bool) async -> Bool {
        await discordService.respondToInteraction(
            id: event.id,
            token: event.token,
            payload: .deferredChannelMessageWithSource(isEphemeral: isEphemeral)
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
        if shouldEdit, response.isEditable {
            await discordService.editInteraction(
                token: event.token,
                payload: response.makeEditPayload()
            )
        } else {
            await discordService.respondToInteraction(
                id: event.id,
                token: event.token,
                payload: response.makeResponse(isEphemeral: forceEphemeral)
            )
        }
    }
}

extension SlashCommand {
    /// Ephemeral means the interaction will only be visible to the user, not the whole guild.
    var isEphemeral: Bool {
        switch self {
        case .link, .autoPings, .howManyCoins, .howManyCoinsApp: return true
        case .help: return false
        }
    }

    var shouldSendAcknowledgment: Bool {
        switch self {
        case .autoPings, .help: return false
        case .link, .howManyCoins, .howManyCoinsApp: return true
        }
    }
}

private enum ModalID {

    enum AutoPingsMode: String {
        case add, remove, test
    }

    enum HelpMode: String {
        case add
    }

    case autoPings(AutoPingsMode, Expression.Kind)
    case help(HelpMode)

    func makeModal() -> Payloads.InteractionResponse.Modal {
        .init(
            custom_id: self.rawValue,
            title: self.title,
            textInputs: self.textInputs
        )
    }

    private var title: String {
        switch self {
        case let .autoPings(autoPingsMode, expressionMode):
            let autoPingsMode = autoPingsMode.rawValue.capitalized
            let expressionMode = expressionMode.UIDescription
            return "\(autoPingsMode) \(expressionMode) Auto-Pings"
        case let .help(helpMode):
            let helpMode = helpMode.rawValue.capitalized
            return "\(helpMode) Help Text"
        }
    }

    private var textInputs: [Interaction.ActionRow.TextInput] {
        switch self {
        case let .autoPings(mode, _):
            switch mode {
            case .add, .remove:
                let texts = Interaction.ActionRow.TextInput(
                    custom_id: "texts",
                    style: .paragraph,
                    label: "Enter the ping-expressions",
                    required: true,
                    placeholder: "Example: vapor, fluent, swift, websocket kit, your-name"
                )
                return [texts]
            case .test:
                let message = Interaction.ActionRow.TextInput(
                    custom_id: "message",
                    style: .paragraph,
                    label: "The text to test against",
                    min_length: 3,
                    required: true,
                    placeholder: "Example: Lorem ipsum dolor sit amet."
                )
                let texts = Interaction.ActionRow.TextInput(
                    custom_id: "texts",
                    style: .paragraph,
                    label: "Enter the ping-expressions",
                    required: false,
                    placeholder: "Leave empty to test your own expressions. Example: vapor, fluent, swift, websocket kit, your-name"
                )
                return [message, texts]
            }
        case let .help(helpMode):
            switch helpMode {
            case .add:
                let name = Interaction.ActionRow.TextInput(
                    custom_id: "name",
                    style: .paragraph,
                    label: "The name of the help-text",
                    min_length: 3,
                    required: true,
                    placeholder: "Example: Setting working directory in Xcode"
                )
                let value = Interaction.ActionRow.TextInput(
                    custom_id: "value",
                    style: .paragraph,
                    label: "The value of the help-text",
                    min_length: 3,
                    required: true,
                    placeholder: """
                    Example:
                    How to set your working directory: <link>
                    """
                )
                return [name, value]
            }
        }
    }
}

/// Used to encode/decode interaction's `custom_id`.
extension ModalID: RawRepresentable {
    var rawValue: String {
        switch self {
        case let .autoPings(autoPingsMode, expressionMode):
            return "auto-pings;\(autoPingsMode.rawValue);\(expressionMode.rawValue)"
        case let .help(helpMode):
            return "help;\(helpMode.rawValue)"
        }
    }

    init? (rawValue: String) {
        let split = rawValue.split(separator: ";")
        if split.count == 3,
           split[0] == "auto-pings",
           let autoPingsMode = AutoPingsMode(rawValue: String(split[1])),
           let expressionMode = Expression.Kind(rawValue: String(split[2])) {
            self = .autoPings(autoPingsMode, expressionMode)
        } else if split.count == 2,
                  split[0] == "help",
                  let helpMode = HelpMode(rawValue: String(split[1])) {
            self = .help(helpMode)
        } else {
            return nil
        }
    }
}

private extension String {
    func divideIntoAutoPingsExpressions(mode: Expression.Kind) -> [Expression] {
        self.split(whereSeparator: { $0 == "," || $0.isNewline })
            .map(String.init)
            .map({ $0.heavyFolded() })
            .filter({ !$0.isEmpty }).map {
                switch mode {
                case .containment:
                    return .contains($0)
                case .exactMatch:
                    return .matches($0)
                }
            }
    }
}

// MARK: - Response

/// This `Response` thing didn't turn out as good as I was hoping for.
/// The approach of abstracting the response using a protocol like this is good imo, still.
/// Just I didn't go full-in on it. Probably need to create a new type for each response type.
/// I'll clean these up sometime soon.
private protocol Response {
    func makeResponse(isEphemeral: Bool) -> Payloads.InteractionResponse
    func makeEditPayload() -> Payloads.EditWebhookMessage
    var isEditable: Bool { get }
}

extension String: Response {
    func makeResponse(isEphemeral: Bool) -> Payloads.InteractionResponse {
        .channelMessageWithSource(.init(embeds: [.init(
            description: String(self.prefix(4_000)),
            color: .vaporPurple
        )], flags: isEphemeral ? [.ephemeral] : nil))
    }

    func makeEditPayload() -> Payloads.EditWebhookMessage {
        .init(embeds: [.init(
            description: String(self.prefix(4_000)),
            color: .vaporPurple
        )])
    }

    var isEditable: Bool { true }
}

extension Payloads.InteractionResponse.Modal: Response {
    func makeResponse(isEphemeral _: Bool) -> Payloads.InteractionResponse {
        .modal(self)
    }

    func makeEditPayload() -> Payloads.EditWebhookMessage {
        Logger(label: "Payloads.InteractionResponse.Modal.makeEditPayload").error(
            "This method is unimplemented and must not be called"
        )
        return .init(content: "Oops, something went wrong")
    }

    /// Responses containing a modal can't be an edit to another message.
    var isEditable: Bool { false }
}

extension Payloads.InteractionResponse.Autocomplete: Response {
    func makeResponse(isEphemeral _: Bool) -> Payloads.InteractionResponse {
        .autocompleteResult(self)
    }

    func makeEditPayload() -> Payloads.EditWebhookMessage {
        Logger(label: "Payloads.InteractionResponse.Autocomplete.makeEditPayload").error(
            "This method must not be called"
        )
        return .init(content: "Oops, something went wrong")
    }

    /// Responses containing a modal can't be an edit to another message.
    var isEditable: Bool { false }
}

// MARK: - Auto-pings help
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

    - Using 'mode' argument You can configure penny to look for exact matches or plain containment. Defaults to '\(Expression.Kind.default.UIDescription)'.

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
