import DiscordBM
import Logging

struct InteractionHandler {
    var logger = Logger(label: "InteractionHandler")
    let event: Interaction
    var pingsService: AutoPingsService {
        ServiceFactory.makePingsService()
    }
    
    init(event: Interaction) {
        self.event = event
        self.logger[metadataKey: "event"] = "\(event)"
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
        guard await DiscordService.shared.memberHasAnyTechnicalRoles(member: member) else {
            logger.warning("Someone tried to use 'auto-pings' but they don't have any of the required roles")
            let rolesString = Constants.TechnicalRoles.allCases.map {
                DiscordUtils.roleMention(id: $0.rawValue)
            }.joined(separator: " ")
            return "Sorry, to make sure Penny can handle the load, this functionality is currently restricted to members with any of these roles: \(rolesString)"
        }
        if options.isEmpty {
            logger.error("Discord did not send required interaction info")
            return "Please provide more options"
        }
        guard let _id = (event.member?.user ?? event.user)?.id else {
            logger.error("Can't find a user's id")
            return "Sorry something went wrong :("
        }
        let discordId = "<@\(_id)>"
        let first = options[0]
        do {
            switch first.name {
            case "add":
                guard let option = first.options?.first,
                      let text = option.value?.asString else {
                    logger.error("Discord did not send required info")
                    return "No 'text' option recognized"
                }
                if text.unicodeScalars.count < 3 {
                    return "The text is less than 3 letters. This is not acceptable"
                }
                try await pingsService.insert([text.foldForPingCommand()], forDiscordID: discordId)
                let escaped = DiscordUtils.escapingSpecialCharacters(text, forChannelType: .text)
                return "Successfully added '\(escaped)' to your pings list"
            case "bulk-add":
                guard let option = first.options?.first,
                      let _text = option.value?.asString else {
                    logger.error("Discord did not send required info")
                    return "No 'text' option recognized"
                }
                let texts = _text.split(separator: ",")
                    .map(String.init)
                    .map({ $0.foldForPingCommand() })
                if texts.contains(where: { $0.unicodeScalars.count < 3 }) {
                    return "One of the texts is less than 3 letters. This is not acceptable"
                }
                try await pingsService.insert(texts, forDiscordID: discordId)
                return """
                Successfully added the followings to you pings-list:
                \(texts.makeAutoPingsTextsList())
                """
            case "remove":
                guard let option = first.options?.first,
                      let text = option.value?.asString else {
                    logger.error("Discord did not send required info")
                    return "No 'text' option recognized"
                }
                try await pingsService.remove([text.foldForPingCommand()], forDiscordID: discordId)
                return "Successfully removed `\(text)` from your pings list"
            case "list":
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
            default:
                logger.error("Unrecognized link option", metadata: ["name": "\(first.name)"])
                return "Option not recognized: \(first.name)"
            }
        } catch {
            logger.error("Pings command error", metadata: ["error": "\(error)"])
            return "Sorry, some errors happened :( please report this to us if it happens again"
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
    
    /// Ephemeral means the interaction will only be visible to the user, not the whole guild.
    var isEphemeral: Bool {
        switch self {
        case .link: return true
        case .autoPings: return true
        }
    }
    
    init? (name: String) {
        switch name {
        case "link": self = .link
        case "auto-pings": self = .autoPings
        default: return nil
        }
    }
}

private extension [String] {
    func makeAutoPingsTextsList() -> String {
        self.sorted().enumerated().map { idx, text -> String in
            let escaped = DiscordUtils.escapingSpecialCharacters(
                text,
                forChannelType: .text
            )
            return "**\(idx + 1).** \(escaped)"
        }.joined(separator: "\n")
    }
}
