import DiscordBM
import Logging
import Models
import JWTKit
import Foundation

private enum Configuration {
    static let faqsNameMaxLength = 100
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
    var faqsService: any FaqsService {
        ServiceFactory.makeFaqsService()
    }
    var discordService: DiscordService { .shared }
    
    private let oops = "Oopsie Woopsie... Something went wrong :("
    
    typealias InteractionOption = Interaction.ApplicationCommand.Option

    
    init(event: Interaction) {
        self.event = event
        self.logger[metadataKey: "event"] = "\(event)"
    }

    private func makeJWTSigners() throws -> JWTSigners? {
        guard let privateKeyString = Constants.accountLinkOAuthPrivKey else {
            fatalError("Missing ACCOUNT_LINKING_OAUTH_FLOW_PRIV_KEY env var")
        }

        let privateKey = try ECDSAKey.private(pem: privateKeyString)

        let signers = JWTSigners()
        signers.use(.es256(key: privateKey))
        return signers
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
            let response = await makeResponseForAutocomplete(
                command: command,
                data: data
            )
            await respond(with: response, shouldEdit: false)
        case let .modalSubmit(modal):
            guard let modalId = ModalID(rawValue: modal.custom_id) else {
                logger.error("Unrecognized modal")
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
        case let .faqs(faqsMode):
            switch faqsMode {
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

                    Value:
                    > \(newValue)
                    """
                }

                if name.unicodeScalars.count > Configuration.faqsNameMaxLength {
                    return """
                    Name cannot be more than \(Configuration.faqsNameMaxLength) characters.

                    Value:
                    > \(newValue)
                    """
                }

                let all = try await faqsService.getAll()

                if let similar = all.first(where: {
                    $0.key.heavyFolded().filter({ !$0.isWhitespace }) == name &&
                    $0.key != name
                })?.key {
                    return """
                    The entered name '\(DiscordUtils.escapingSpecialCharacters(name))' is too similar to another name '\(DiscordUtils.escapingSpecialCharacters(similar))' while not being equal.
                    This will cause ambiguity for users.

                    Value:
                    \(newValue)
                    """
                }

                if let value = all[name] {
                    return """
                    A FAQ with name '\(name)' already exists. Please remove it first.

                    Value:
                    \(newValue)

                    Old value:
                    \(value)
                    """
                }

                if name.isEmpty || newValue.isEmpty {
                    return "'name' or 'value' seem empty to me :("
                }
                /// The response of this command is ephemeral so members feel free to add faqs.
                /// We will log this action so we can know if something malicious is happening.
                logger.notice("Will add a FAQ", metadata: [
                    "name": .string(name),
                    "value": .string(newValue),
                ])

                discardingResult {
                    try await faqsService.insert(name: name, value: newValue)
                }

                return """
                Added a new FAQ with name '\(name)':

                \(newValue)
                """
            case let .edit(nameHash, _):
                guard let name = try await faqsService.getName(hash: nameHash) else {
                    logger.warning(
                        "This should be very rare ... a name doesn't exist anymore to edit",
                        metadata: ["nameHash": .stringConvertible(nameHash)]
                    )
                    return "The name no longer exists!"
                }
                let newValue = try modal.components
                    .requireComponent(customId: "value")
                    .requireTextInput()
                    .value.requireValue()

                if name.isEmpty || newValue.isEmpty {
                    return "'name' or 'value' seem empty to me :("
                }
                /// The response of this command is ephemeral so members feel free to add faqs.
                /// We will log this action so we can know if something malicious is happening.
                logger.notice("Will edit a FAQ", metadata: [
                    "name": .string(name),
                    "value": .string(newValue),
                ])

                discardingResult {
                    try await faqsService.insert(name: name, value: newValue)
                }

                return """
                Edited a FAQ with name '\(name)':

                \(newValue)
                """
            case let .rename(nameHash, _):
                guard let oldName = try await faqsService.getName(hash: nameHash) else {
                    logger.warning(
                        "This should be very rare ... a name doesn't exist anymore to edit",
                        metadata: ["nameHash": .stringConvertible(nameHash)]
                    )
                    return "The name no longer exists!"
                }
                guard let value = try await faqsService.get(name: oldName) else {
                    logger.warning(
                        "This should be very rare ... a name doesn't have a value anymore",
                        metadata: ["nameHash": .stringConvertible(nameHash)]
                    )
                    return "Oopsie Woopsie, there is no value specified for this name at all!"
                }
                let name = try modal.components
                    .requireComponent(customId: "name")
                    .requireTextInput()
                    .value.requireValue()

                if name.isEmpty {
                    return "'name' seems empty to me :("
                }
                /// The response of this command is ephemeral so members feel free to add faqs.
                /// We will log this action so we can know if something malicious is happening.
                logger.notice("Will rename a FAQ", metadata: [
                    "name": .string(name),
                    "value": .string(value),
                ])

                discardingResult {
                    try await faqsService.insert(name: name, value: value)
                    try await faqsService.remove(name: oldName)
                }

                return """
                Renamed a FAQ from '\(oldName)' to '\(name)':

                \(value)
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
            case .github:
                return try await handleGitHubCommand(options: options)
            case .autoPings:
                return try await handlePingsCommand(options: options)
            case .faqs:
                return try await handleFaqsCommand(options: options)
            case .howManyCoins:
                return try await handleHowManyCoinsCommand(options: options)
            case .howManyCoinsApp:
                return try await handleHowManyCoinsAppCommand()
            }
        } catch {
            logger.report("Command error", error: error)
            return oops
        }
    }
    
    func handleGitHubCommand(options: [InteractionOption]) async throws -> (any Response)? {
        let discordID = try (event.member?.user).requireValue().id
        let first = try options.first.requireValue()
        let subcommand = try GitHubSubCommand(rawValue: first.name).requireValue()

        switch subcommand {
        case .link:
            let clientID = Constants.ghOAuthClientId!
            let jwt = GHOAuthPayload(
                discordID: discordID, 
                interactionToken: event.token
            )
            guard let signers = try makeJWTSigners() else {
                logger.error("Failed to make JWT signer")
                return oops
            }
            let state = try signers.sign(jwt)
            let url = "https://github.com/login/oauth/authorize?client_id=\(clientID)&state=\(state)"
            return Payloads.EditWebhookMessage(
                embeds: [.init(
                    description: """
                    Click the link below to authorize Vapor:

                    > This is a one-time authorization to your public info in a read-only manner as GitHub mentions, so Penny can confirm you own the Github account.
                    > Feel free to revoke Penny's access from your GitHub account afterwards.

                    [**Authorize**](\(url))
                    """,
                    color: .vaporPurple
                )]
            )
        case .unlink:
            return "This command is still a WIP. Unlinking discordId: \(discordID)"
        case .whoAmI:
            let user = "<@\(discordID)>"
            let response = try await coinService.getGitHubID(of: user)
            switch response {
            case .notLinked:
                return "You don't have any linked GitHub accounts."
            case .userName(let username):
                let encodedUsername = username.addingPercentEncoding(
                    withAllowedCharacters: .urlPathAllowed
                ) ?? username
                let url = "https://github.com/\(encodedUsername)"
                return "Your linked GitHub account is: [\(username)](\(url))"
            }
        }
    }
    
    func handlePingsCommand(options: [InteractionOption]) async throws -> (any Response)? {
        let discordId = try (event.member?.user).requireValue().id
        let first = try options.first.requireValue()
        let subcommand = try AutoPingsSubCommand(rawValue: first.name).requireValue()

        switch subcommand {
        case .help, .list, .remove:
            guard await sendAcknowledgement(isEphemeral: true) else { return nil }
        case .add, .bulkRemove, .test:
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
        case .remove:
            let expressionInput = try first
                .requireOption(named: "expression")
                .requireString()
            guard let hash = Int(expressionInput) else {
                return "Malformed expression value: '\(expressionInput)'"
            }
            guard let expression = try await pingsService.getExpression(hash: hash) else {
                return "Could not find any expression matching your input"
            }
            discardingResult {
                try await pingsService.remove([expression], forDiscordID: discordId)
            }

            return """
            Successfully removed the followings from your pings-list:
            \([expression].makeExpressionListForDiscord())
            """
        case .add:
            let mode = try self.requireExpressionMode(first.options)
            let modalId = ModalID.autoPings(.add, mode)
            return modalId.makeModal()
        case .bulkRemove:
            let mode = try self.requireExpressionMode(first.options)
            let modalId = ModalID.autoPings(.remove, mode)
            return modalId.makeModal()
        case .test:
            let mode = try self.requireExpressionMode(first.options)
            let modalId = ModalID.autoPings(.test, mode)
            return modalId.makeModal()
        }
    }

    func handleFaqsCommand(options: [InteractionOption]) async throws -> (any Response)? {
        let first = try options.first.requireValue()
        let subcommand = try FaqsSubCommand(rawValue: first.name).requireValue()
        switch subcommand {
        case .get:
            var ephemeralOverride: Bool?
            if let option = first.option(named: "ephemeral"),
               case let .bool(bool) = option.value {
                ephemeralOverride = bool
            }
            guard await sendAcknowledgement(
                isEphemeral: ephemeralOverride ?? false
            ) else { return nil }
        case .remove:
            /// This is ephemeral so members feel free to remove stuff,
            /// but we will log this action so we can know if something malicious is happening.
            guard await sendAcknowledgement(isEphemeral: true) else { return nil }
        case .add, .edit, .rename:
            /// Uses modals so can't send an acknowledgment first.
            break
        }
        switch subcommand {
        case .get:
            let name = try first.options
                .requireValue()
                .requireOption(named: "name")
                .requireString()
            if let value = try await faqsService.get(name: name) {
                return value
            } else {
                return "No FAQ with name '\(name)' exists at all"
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
            guard let value = try await faqsService.get(name: name) else {
                return "No FAQ with name '\(name)' exists at all"
            }
            logger.warning("Will remove a FAQ", metadata: [
                "name": .string(name),
                "value": .string(value),
            ])

            discardingResult {
                try await faqsService.remove(name: name)
            }

            return "Removed a FAQ with name '\(name)'"
        case .add:
            if let accessLevelError = try await faqsCommandAccessLevelErrorIfNeeded() {
                return accessLevelError
            }
            let modalId = ModalID.faqs(.add)
            return modalId.makeModal()
        case .edit:
            let name = try first.options
                .requireValue()
                .requireOption(named: "name")
                .requireString()
            if let accessLevelError = try await faqsCommandAccessLevelErrorIfNeeded() {
                return accessLevelError
            }
            if let value = try await faqsService.get(name: name) {
                let modalId = ModalID.faqs(.edit(nameHash: name.hash, value: value))
                return modalId.makeModal()
            } else {
                return "No FAQ with name '\(name)' exists at all"
            }
        case .rename:
            let name = try first.options
                .requireValue()
                .requireOption(named: "name")
                .requireString()
            if let accessLevelError = try await faqsCommandAccessLevelErrorIfNeeded() {
                return accessLevelError
            }
            if try await faqsService.get(name: name) != nil {
                let modalId = ModalID.faqs(.rename(nameHash: name.hash, name: name))
                return modalId.makeModal()
            } else {
                return "No FAQ with name '\(name)' exists at all"
            }
        }
    }

    /// Returns a `String` if there is an access-levelerror. Otherwise `nil`.
    func faqsCommandAccessLevelErrorIfNeeded() async throws -> String? {
        if await discordService.memberHasRolesForElevatedRestrictedCommandsAccess(
            member: try event.member.requireValue()
        ) {
            return nil
        } else {
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
    }

    func makeResponseForAutocomplete(
        command: SlashCommand,
        data: Interaction.ApplicationCommand
    ) async -> Payloads.InteractionResponse.Autocomplete {
        do {
            switch command {
            case .autoPings:
                return try await handleAutoPingsAutocomplete(data: data)
            case .faqs:
                return try await handleFaqsAutocomplete(data: data)
            case .github, .howManyCoins, .howManyCoinsApp:
                logger.error("Unrecognized command with autocomplete")
                return Payloads.InteractionResponse.Autocomplete(
                    choices: [.init(name: "Failure", value: .string(self.oops))]
                )
            }
        } catch {
            logger.report("Autocomplete generation error", error: error, metadata: [
                "command": .string(command.rawValue)
            ])
            return Payloads.InteractionResponse.Autocomplete(
                choices: [.init(name: "Failure", value: .string(self.oops))]
            )
        }
    }

    func handleAutoPingsAutocomplete(
        data: Interaction.ApplicationCommand
    ) async throws -> Payloads.InteractionResponse.Autocomplete {
        let first = try (data.options?.first).requireValue()
        let name = try first.options
            .requireValue()
            .requireOption(named: "expression")
            .requireString()

        let foldedName = name.heavyFolded()
        let userId = try (event.member?.user?.id).requireValue()
        let all = try await pingsService.get(discordID: userId)
        let queried: ArraySlice<S3AutoPingItems.Expression>
        if foldedName.isEmpty {
            queried = ArraySlice(all
                .sorted { $0.innerValue > $1.innerValue }
                .sorted { $0.kind.priority > $1.kind.priority }
                .prefix(25)
            )
        } else {
            queried = all
                .filter { $0.innerValue.heavyFolded().contains(foldedName) }
                .sorted { $0.innerValue > $1.innerValue }
                .sorted { $0.kind.priority > $1.kind.priority }
                .prefix(25)
        }
        

        return .init(choices: queried.map { expression in
            let name = "\(expression.kind.UIDescription) - \(expression.innerValue)"
            return .init(
                name: name.unicodesPrefix(100),
                value: .string("\(expression.hashValue)")
            )
        })
    }

    func handleFaqsAutocomplete(
        data: Interaction.ApplicationCommand
    ) async throws -> Payloads.InteractionResponse.Autocomplete {
        let first = try (data.options?.first).requireValue()
        let name = try first.options
            .requireValue()
            .requireOption(named: "name")
            .requireString()
        let foldedName = name.heavyFolded()
        let all = try await faqsService.getAll().map(\.key)
        let queried: ArraySlice<String>
        if foldedName.isEmpty {
            queried = ArraySlice(all.sorted { $0 > $1 }.prefix(25))
        } else {
            queried = all
                .filter { $0.heavyFolded().contains(foldedName) }
                .sorted { $0 > $1 }
                .prefix(25)
        }
        return Payloads.InteractionResponse.Autocomplete(
            choices: queried.map { name in
                ApplicationCommand.Option.Choice(
                    name: name,
                    value: .string(name)
                )
            }
        )
    }
    
    func requireExpressionMode(_ options: [InteractionOption]?) throws -> Expression.Kind {
        let optionValue = try options
            .requireValue()
            .requireOption(named: "mode")
            .requireString()
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
    
    func handleHowManyCoinsCommand(options: [InteractionOption]) async throws -> String {
        let user: String
        if let userOption = options.first?.value?.asString {
            user = "<@\(userOption)>"
        } else {
            let author = event.member?.user ?? event.user
            let id = try (author?.id).requireValue()
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
        case .github, .autoPings, .howManyCoins, .howManyCoinsApp: return true
        case .faqs: return false
        }
    }

    var shouldSendAcknowledgment: Bool {
        switch self {
        case .autoPings, .faqs: return false
        case .github, .howManyCoins, .howManyCoinsApp: return true
        }
    }
}

//MARK: - ModalID

private enum ModalID {

    enum AutoPingsMode: String {
        case add, remove, test
    }

    enum FaqsMode {
        case add
        /// Using the hash of the name to make sure we don't exceed Discord's
        /// custom-id length limit (currently 100 characters).
        ///
        /// `value` is passed to the modal, and will not be populated when
        /// this enum case is re-constructed from a custom-id.
        case edit(nameHash: Int, value: String?)
        /// `name` is passed to the modal, and will not be populated when
        /// this enum case is re-constructed from a custom-id.
        case rename(nameHash: Int, name: String?)

        var name: String {
            switch self {
            case .add:
                return "Add"
            case .edit:
                return "Edit"
            case .rename:
                return "Rename"
            }
        }

        func makeForCustomId() -> String {
            switch self {
            case .add:
                return "add"
            case .edit(let nameHash, _):
                return "edit-\(nameHash)"
            case .rename(let nameHash, _):
                return "rename-\(nameHash)"
            }
        }

        init? (customIdPart part: String) {
            if part == "add" {
                self = .add
            } else if part.hasPrefix("edit-"), let hash = Int(part.dropFirst(5)) {
                self = .edit(nameHash: hash, value: nil)
            } else if part.hasPrefix("rename-"), let hash = Int(part.dropFirst(7)) {
                self = .rename(nameHash: hash, name: nil)
            } else {
                return nil
            }
        }
    }

    case autoPings(AutoPingsMode, Expression.Kind)
    case faqs(FaqsMode)

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
        case let .faqs(faqsMode):
            return "\(faqsMode.name) FAQ Text"
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
        case let .faqs(faqsMode):
            switch faqsMode {
            case .add:
                let name = Interaction.ActionRow.TextInput(
                    custom_id: "name",
                    style: .short,
                    label: "The name of the FAQ",
                    min_length: 3,
                    max_length: Configuration.faqsNameMaxLength,
                    required: true,
                    placeholder: "Example: Setting working directory in Xcode"
                )
                let value = Interaction.ActionRow.TextInput(
                    custom_id: "value",
                    style: .paragraph,
                    label: "The value of the FAQ",
                    min_length: 3,
                    required: true,
                    placeholder: """
                    Example:
                    How to set your working directory: <link>
                    """
                )
                return [name, value]
            case .edit(_, let value):
                let value = Interaction.ActionRow.TextInput(
                    custom_id: "value",
                    style: .paragraph,
                    label: "The value of the FAQ",
                    min_length: 3,
                    required: true,
                    value: value,
                    placeholder: value == nil ? """
                    Example:
                    How to set your working directory: <link>
                    """ : nil
                )
                return [value]
            case .rename(_, let name):
                let name = Interaction.ActionRow.TextInput(
                    custom_id: "name",
                    style: .short,
                    label: "The name of the FAQ",
                    min_length: 3,
                    max_length: Configuration.faqsNameMaxLength,
                    required: true,
                    value: name,
                    placeholder: name == nil ? "Example: Setting working directory in Xcode" : nil
                )
                return [name]
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
        case let .faqs(faqsMode):
            return "faqs;\(faqsMode.makeForCustomId())"
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
                  split[0] == "faqs",
                  let faqsMode = FaqsMode(customIdPart: String(split[1])) {
            self = .faqs(faqsMode)
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
            description: String(self.unicodesPrefix(4_000)),
            color: .vaporPurple
        )], flags: isEphemeral ? [.ephemeral] : nil))
    }

    func makeEditPayload() -> Payloads.EditWebhookMessage {
        .init(embeds: [.init(
            description: String(self.unicodesPrefix(4_000)),
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

extension Payloads.EditWebhookMessage: Response {
    func makeResponse(isEphemeral: Bool) -> Payloads.InteractionResponse {
        Logger(label: "Payloads.EditWebhookMessage.makeResponse").error(
            "This method is unimplemented and must not be called"
        )
        return .channelMessageWithSource(
            .init(content: "Oops, something went wrong")
        )
    }

    func makeEditPayload() -> Payloads.EditWebhookMessage {
        self
    }

    var isEditable: Bool { true }
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
