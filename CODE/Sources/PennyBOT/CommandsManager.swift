import DiscordBM
import Logging

struct CommandsManager {
    func registerCommands() async {
        await DiscordService.shared.overwriteCommands([
            .link,
            .ping,
            .howManyCoins,
            .howManyCoinsApp
        ])
    }
}

private extension Payloads.ApplicationCommandCreate {
    static let link = Payloads.ApplicationCommandCreate(
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
    
    static let expressionModeOption: ApplicationCommand.Option = .init(
        type: .string,
        name: "mode",
        description: "The expression mode. Use '\(ExpressionMode.default.rawValue)' by default",
        required: true,
        choices: ExpressionMode.allCases.map(\.rawValue).map {
            .init(name: $0, value: .string($0))
        }
    )
    
    static let ping = Payloads.ApplicationCommandCreate(
        name: "auto-pings",
        description: "Configure Penny to ping you when certain someone uses a word/text",
        options: [
            .init(
                type: .subCommand,
                name: "help",
                description: "Help about how auto-pings works"
            ),
            .init(
                type: .subCommand,
                name: "add",
                description: "Add multiple texts to be pinged for (Slack compatible)",
                options: [expressionModeOption]
            ),
            .init(
                type: .subCommand,
                name: "remove",
                description: "Remove multiple ping texts",
                options: [expressionModeOption]
            ),
            .init(
                type: .subCommand,
                name: "list",
                description: "See what you'll get pinged for"
            ),
            .init(
                type: .subCommand,
                name: "test",
                description: "Test if a message triggers an auto-ping text",
                options: [expressionModeOption]
            )
        ],
        dm_permission: false
    )
    
    static let howManyCoins = Payloads.ApplicationCommandCreate(
        name: "how-many-coins",
        description: "See how many coins members have",
        options: [.init(
            type: .user,
            name: "member",
            description: "The member to check their coin count"
        )],
        dm_permission: false
    )
    
    static let howManyCoinsApp = Payloads.ApplicationCommandCreate(
        name: "How Many Coins?",
        dm_permission: false,
        type: .user
    )
}
