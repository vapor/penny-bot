import Foundation
import DiscordBM
import Logging

struct SlashCommandHandler {
    let discordClient: DiscordClient
    let logger: Logger
    let guildId = "431917998102675485"
    
    func registerCommands() {
        /// Optimally we would register command only if not already registered,
        /// because currently there is a 100 commands per day limit. For now it
        /// should not be a problem, if the command is available, it'll just be overriden.
        let linkCommand = SlashCommand(
            name: "link",
            description: "Links your accounts in Penny",
            options: [
                .init(
                    type: .subCommand,
                    name: "discord",
                    description: "Link your Discord account",
                    options: [.init(
                        type: .string,
                        name: "id",
                        description: "Your Discord account ID",
                        required: true
                    )]
                ),
                .init(
                    type: .subCommand,
                    name: "github",
                    description: "Link your Github account",
                    options: [.init(
                        type: .string,
                        name: "id",
                        description: "Your Github account ID",
                        required: true
                    )]
                ),
                .init(
                    type: .subCommand,
                    name: "slack",
                    description: "Link your Slack account",
                    options: [.init(
                        type: .string,
                        name: "id",
                        description: "Your Slack account ID",
                        required: true
                    )]
                )
            ]
        )
        
        Task {
            do {
                let apiResponse = try await discordClient.createApplicationGlobalCommand(
                    payload: linkCommand
                ).raw
                if !(200..<300).contains(apiResponse.status.code) {
                    logger.error("Received non-200 status from Discord API for slash commands: \(apiResponse)")
                }
            } catch {
                logger.error("Discord Client error: \(error)")
            }
        }
    }
}
