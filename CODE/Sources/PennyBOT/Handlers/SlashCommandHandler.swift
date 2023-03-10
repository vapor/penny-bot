import DiscordBM
import Logging

struct SlashCommandHandler {
    func registerCommands() async {
        /// Optimally we would register command only if not already registered,
        /// because currently there is a 100 commands per day limit. For now it
        /// should not be a problem, if the command is available, it'll just be overridden.
        let commands: [RequestBody.ApplicationCommandCreate] = [.link, .ping]
        for command in commands {
            await DiscordService.shared.createSlashCommand(payload: command)
        }
    }
}

private extension RequestBody.ApplicationCommandCreate {
    static let link = RequestBody.ApplicationCommandCreate(
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
        ],
        dm_permission: false
    )
    
    static let ping = RequestBody.ApplicationCommandCreate(
        name: "automated-pings",
        description: "Penny pings you when certain things happen in Vapor's server",
        options: [
            .init(
                type: .subCommand,
                name: "add",
                description: "Ping when a message contains a text (case & diacritic insensitive)",
                options: [.init(
                    type: .string,
                    name: "text",
                    description: "The text you want to be pinged for",
                    required: true
                )]
            ),
            .init(
                type: .subCommand,
                name: "bulk-add",
                description: "Ping when a message contains these texts  (case & diacritic insensitive)",
                options: [.init(
                    type: .string,
                    name: "texts",
                    description: "The texts you want to be pinged for, separated by a comma (,)",
                    required: true
                )]
            ),
            .init(
                type: .subCommand,
                name: "remove",
                description: "Remove pings for certain texts",
                options: [.init(
                    type: .string,
                    name: "text",
                    description: "The text you don't want to be notified for anymore",
                    required: true
                )]
            ),
            .init(
                type: .subCommand,
                name: "list",
                description: "See what you're subscribed to"
            )
        ],
        dm_permission: false
    )
}
