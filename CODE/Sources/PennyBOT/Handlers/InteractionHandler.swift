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
        guard case let .applicationCommand(data) = event.data else {
            logger.error("Discord did not send required interaction info", metadata: [
                "id": .stringConvertible(0),
                "event": "\(event)"
            ])
            return "Failed to recognize the interaction"
        }
        let options = data.options ?? []
        switch data.name {
        case "link":
            if options.isEmpty {
                logger.error("Discord did not send required interaction info", metadata: [
                    "id": .stringConvertible(2),
                    "event": "\(event)"
                ])
                return "Please provide more options"
            }
            let first = options[0]
            guard let id = first.options?.first?.value?.asString else {
                logger.error("Discord did not send required interaction info", metadata: [
                    "id": .stringConvertible(3),
                    "event": "\(event)"
                ])
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
                logger.error("Unrecognized link option", metadata: [
                    "name": .string(first.name)
                ])
                return "Option not recognized: \(first.name)"
            }
        default:
            logger.error("Unrecognized command", metadata: ["event": "\(event)"])
            return "Command not recognized"
        }
    }
    
    /// Returns if the acknowledgement was successfully sent
    private func sendInteractionAcknowledgement() async -> Bool {
        do {
            let apiResponse = try await discordClient.createInteractionResponse(
                id: event.id,
                token: event.token,
                payload: .init(type: .deferredChannelMessageWithSource)
            )
            if !(200..<300).contains(apiResponse.status.code) {
                logger.report(
                    "Received non-200 status from Discord API for interaction acknowledgement",
                    response: apiResponse
                )
                return false
            } else {
                return true
            }
        } catch {
            logger.error("Discord Client error", metadata: ["error": "\(error)"])
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
                logger.report(
                    "Received non-200 status from Discord API for interaction",
                    response: apiResponse
                )
            }
        } catch {
            logger.error("Discord Client error", metadata: ["error": "\(error)"])
        }
    }
}
