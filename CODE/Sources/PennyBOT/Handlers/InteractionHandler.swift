import Logging
import DiscordBM

struct InteractionHandler {
    let discordClient: any DiscordClient
    let logger: Logger
    let event: Interaction
    
    func handle() async {
        guard await sendInteractionAcknowledgement() else { return }
        let response = processAndMakeResponse()
        await respond(with: response)
    }
    
    private func processAndMakeResponse() -> String {
        guard let name = event.data?.name else {
            logger.error("Discord did not send required info. ID: 1. Event: \(event)")
            return "Failed to recognize the interaction"
        }
        let options = event.data?.options ?? []
        switch name {
        case "link":
            return handleLinkCommand(options: options)
        case "automated-pings":
            return handlePingsCommand(options: options)
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
    
    func handlePingsCommand(options: [Interaction.Data.Option]) -> String {
        if options.isEmpty {
            logger.error("Discord did not send required interaction info. ID: 4. Event: \(event)")
            return "Please provide more options"
        }
        let first = options[0]
        switch first.name {
        case "on-text":
            guard let option = first.options?.first,
                  let text = option.value?.asString else {
                logger.error("Discord did not send required info. ID: 5. Event: \(event)")
                return "No 'text' option recognized"
            }
            return "'on-text' is still a WIP: \(text)"
        case "remove":
            guard let option = first.options?.first,
                  let text = option.value?.asString else {
                logger.error("Discord did not send required info. ID: 5. Event: \(event)")
                return "No 'text' option recognized"
            }
            return "'remove' is still a WIP: \(text)"
        case "list":
            return "'list' is still a WIP"
        case "disable":
            return "'disable' is still a WIP"
        case "enable":
            return "'enable' is still a WIP"
        default:
            logger.error("Unrecognized link option: \(first.name)")
            return "Option not recognized: \(first.name)"
        }
    }
    
    /// Returns if the acknowledgement was successfully sent
    private func sendInteractionAcknowledgement() async -> Bool {
        do {
            let apiResponse = try await discordClient.createInteractionResponse(
                id: event.id,
                token: event.token,
                payload: .init(type: .messageEditWithLoadingState)
            ).httpResponse
            if !(200..<300).contains(apiResponse.status.code) {
                logger.error("Received non-200 status from Discord API for interaction acknowledgement: \(apiResponse)")
                return false
            } else {
                return true
            }
        } catch {
            logger.error("Discord Client error: \(error)")
            return false
        }
    }
    
    private func respond(with response: String) async {
        do {
            let apiResponse = try await discordClient.editInteractionResponse(
                token: event.token,
                payload: .init(
                    embeds: [.init(
                        description: response,
                        color: .vaporPurple
                    )]
                )
            )
            if !(200..<300).contains(apiResponse.status.code) {
                logger.error("Received non-200 status from Discord API for interaction: \(apiResponse)")
            }
        } catch {
            logger.error("Discord Client error: \(error)")
        }
    }
}
