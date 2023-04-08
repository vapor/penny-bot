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
    
    static let expressionModeOption: ApplicationCommand.Option = .init(
        type: .string,
        name: "mode",
        description: "The expression mode. Defaults to '\(ExpressionMode.default.rawValue)'",
        choices: ExpressionMode.allCases.map(\.rawValue).map {
            .init(name: $0, value: .string($0))
        }
    )
    
    static let ping = RequestBody.ApplicationCommandCreate(
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
                options: [
                    .init(
                        type: .string,
                        name: "texts",
                        description: "Exact texts to be pinged for, separated by ','. Insensitive to cases, diacritics & punctuations",
                        required: true
                    ),
                    expressionModeOption
                ]
            ),
            .init(
                type: .subCommand,
                name: "remove",
                description: "Remove multiple ping texts",
                options: [
                    .init(
                        type: .string,
                        name: "texts",
                        description: "Texts you don't want to be pinged for anymore, separated by ','",
                        required: true
                    ),
                    expressionModeOption
                ]
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
                options: [
                    .init(
                        type: .string,
                        name: "message",
                        description: "The message that is supposed to trigger the texts",
                        required: true
                    ),
                    .init(
                        type: .string,
                        name: "texts",
                        description: "The texts to be test-triggered"
                    ),
                    expressionModeOption
                ]
            )
        ],
        dm_permission: false
    )
    
    static let howManyCoins = RequestBody.ApplicationCommandCreate(
        name: "how-many-coins",
        description: "See how many coins members have",
        options: [.init(
            type: .user,
            name: "member",
            description: "The member to check their coin count"
        )],
        dm_permission: false
    )
    
    static let howManyCoinsApp = RequestBody.ApplicationCommandCreate(
        name: "How Many Coins?",
        dm_permission: false,
        type: .user
    )
}
