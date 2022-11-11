import DiscordBM
import Logging

struct InteractionHandler {
    let logger: Logger
    let event: Interaction
    var pingsService: AutoPingsService {
        ServiceFactory.makePingsService()
    }
    
    func handle() async {
        guard await sendInteractionAcknowledgement() else { return }
        let response = await processAndMakeResponse()
        await respond(with: response)
    }
    
    private func processAndMakeResponse() async -> String {
        guard let name = event.data?.name else {
            logger.error("Discord did not send required info. ID: 1. Event: \(event)")
            return "Failed to recognize the interaction"
        }
        let options = event.data?.options ?? []
        switch name {
        case "link":
            return handleLinkCommand(options: options)
        case "automated-pings":
            return await handlePingsCommand(options: options)
        default:
            logger.error("Unrecognized command. Event: \(event)")
            return "Command not recognized"
        }
    }
    
    func handleLinkCommand(options: [Interaction.Data.Option]) -> String {
        if options.isEmpty {
            logger.error("Discord did not send required info. ID: 2. Event: \(event)")
            return "Please provide more options"
        }
        let first = options[0]
        guard let id = first.options?.first?.value?.asString else {
            logger.error("Discord did not send required info. ID: 3. Event: \(event)")
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
            logger.error("Unrecognized link option: \(first.name)")
            return "Option not recognized: \(first.name)"
        }
    }
    
    func handlePingsCommand(options: [Interaction.Data.Option]) async -> String {
        if options.isEmpty {
            logger.error("Discord did not send required interaction info. ID: 4. Event: \(event)")
            return "Please provide more options"
        }
        guard event.guild_id == nil else {
            await sendDM("Hey 👋 please use the slash command here again :)")
            return "Please DM me so we can talk about this privately :)"
        }
        guard let _id = (event.member?.user ?? event.user)?.id else {
            logger.error("Can't find a user's id. Event: \(event)")
            return "Can't find your user id :("
        }
        let discordId = "<@\(_id)>"
        let first = options[0]
        do {
            switch first.name {
            case "add":
                guard let option = first.options?.first,
                      let text = option.value?.asString else {
                    logger.error("Discord did not send required info. ID: 5. Event: \(event)")
                    return "No 'text' option recognized"
                }
                if text.unicodeScalars.count < 3 {
                    return "The text is less than 3 letters. This is not acceptable"
                }
                try await pingsService.insert([text.foldForPingCommand()], forDiscordID: discordId)
                return "Successfully added `\(text)` to your pings list"
            case "bulk-add":
                guard let option = first.options?.first,
                      let _text = option.value?.asString else {
                    logger.error("Discord did not send required info. ID: 5. Event: \(event)")
                    return "No 'text' option recognized"
                }
                let texts = _text.split(separator: ",")
                    .map(String.init)
                    .map({ $0.foldForPingCommand() })
                if texts.contains(where: { $0.unicodeScalars.count < 3 }) {
                    return "One of the texts is less than 3 letters. This is not acceptable"
                }
                try await pingsService.insert(texts, forDiscordID: discordId)
                let textsList = texts.map({ "`\($0)`" }).joined(separator: "\n")
                return """
                Successfully added
                \(textsList)
                to your pings list
                """
            case "remove":
                guard let option = first.options?.first,
                      let text = option.value?.asString else {
                    logger.error("Discord did not send required info. ID: 5. Event: \(event)")
                    return "No 'text' option recognized"
                }
                try await pingsService.remove([text.foldForPingCommand()], forDiscordID: discordId)
                return "Successfully removed `\(text)` from your pings list"
            case "list":
                let list = try await pingsService
                    .get(discordID: discordId)
                    .enumerated().map { idx, text in
                        "**\(idx).** `\(text)`"
                    }.joined(separator: "\n")
                return list
            default:
                logger.error("Unrecognized link option: \(first.name)")
                return "Option not recognized: \(first.name)"
            }
        } catch {
            logger.error("An error happened. Error: \(error)")
            return "Sorry some errors happened :( please report this to us id it happens again."
        }
    }
    
    /// Returns `true` if the acknowledgement was successfully sent
    private func sendInteractionAcknowledgement() async -> Bool {
        await DiscordService.shared.respondToInteraction(
            id: event.id,
            token: event.token,
            payload: .init(type: .messageEditWithLoadingState)
        )
    }
    
    private func respond(with response: String) async {
        await DiscordService.shared.editInteraction(
            token: event.token,
            payload: .init(
                embeds: [.init(
                    description: response,
                    color: .vaporPurple
                )]
            )
        )
    }
    
    private func sendDM(_ response: String) async {
        guard let userId = (event.member?.user ?? event.user)?.id else {
            logger.error("Can't find user id. Event: \(event)")
            return
        }
        await DiscordService.shared.sendDM(
            userId: userId,
            payload: .init(
                embeds: [.init(
                    description: response,
                    color: .vaporPurple
                )]
            )
        )
    }
}
