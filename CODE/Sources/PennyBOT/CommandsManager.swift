import DiscordBM
import PennyModels
import Logging

struct CommandsManager {
    func registerCommands() async {
        let commands = makeCommands()
        await DiscordService.shared.overwriteCommands(commands)
    }

    private func makeCommands() -> [Payloads.ApplicationCommandCreate] {
        SlashCommand.allCases.map { command in
            Payloads.ApplicationCommandCreate(
                name: command.rawValue,
                description: command.description,
                options: command.options,
                dm_permission: command.dmPermission,
                type: command.type
            )
        }
    }
}

enum SlashCommand: String, CaseIterable {
    case link
    case autoPings = "auto-pings"
    case help
    case howManyCoins = "how-many-coins"
    case howManyCoinsApp = "How Many Coins?"

    var description: String? {
        switch self {
        case .link:
            return "Links your accounts in Penny"
        case .autoPings:
            return "Configure Penny to ping you when certain someone uses a word/text"
        case .help:
            return "Ask Penny to send a predefined help message"
        case .howManyCoins:
            return "See how many coins members have"
        case .howManyCoinsApp:
            return nil
        }
    }

    var options: [ApplicationCommand.Option]? {
        switch self {
        case .link:
            return LinkSubCommand.allCases.map { subCommand in
                ApplicationCommand.Option(
                    type: .subCommand,
                    name: subCommand.rawValue,
                    description: subCommand.description,
                    options: subCommand.options
                )
            }
        case .autoPings:
            return AutoPingsSubCommand.allCases.map { subCommand in
                ApplicationCommand.Option(
                    type: .subCommand,
                    name: subCommand.rawValue,
                    description: subCommand.description,
                    options: subCommand.options
                )
            }
        case .help:
            return HelpSubCommand.allCases.map { subCommand in
                ApplicationCommand.Option(
                    type: .subCommand,
                    name: subCommand.rawValue,
                    description: subCommand.description,
                    options: subCommand.options
                )
            }
        case .howManyCoins:
            return [.init(
                type: .user,
                name: "member",
                description: "The member to check their coin count"
            )]
        case .howManyCoinsApp:
            return nil
        }
    }

    var dmPermission: Bool {
        return false
    }

    var type: ApplicationCommand.Kind? {
        switch self {
        case .howManyCoinsApp:
            return .user
        case .link, .autoPings, .help, .howManyCoins:
            return nil
        }
    }
}

enum LinkSubCommand: String, CaseIterable {
    case discord, github, slack

    var description: String {
        switch self {
        case .discord:
            return "Link your Discord account"
        case .github:
            return "Link your Github account"
        case .slack:
            return "Link your Slack account"
        }
    }

    var options: [ApplicationCommand.Option] {
        switch self {
        case .discord: return [.init(
            type: .string,
            name: "id",
            description: "Your Discord account ID",
            required: true
        )]
        case .github: return [.init(
            type: .string,
            name: "id",
            description: "Your Github account ID",
            required: true
        )]
        case .slack: return [.init(
            type: .string,
            name: "id",
            description: "Your Slack account ID",
            required: true
        )]
        }
    }
}

enum AutoPingsSubCommand: String, CaseIterable {
    case help, add, remove, list, test

    var description: String {
        switch self {
        case .help:
            return "Help about how auto-pings works"
        case .add:
            return "Add multiple texts to be pinged for (Slack compatible)"
        case .remove:
            return "Remove multiple ping texts"
        case .list:
            return "See what you'll get pinged for"
        case .test:
            return "Test if a message triggers an auto-ping text"
        }
    }

    var options: [ApplicationCommand.Option] {
        switch self {
        case .add, .remove, .test:
            return [Self.expressionModeOption]
        case .help, .list:
            return []
        }
    }

    private static let expressionModeOption = ApplicationCommand.Option(
        type: .string,
        name: "mode",
        description: "The expression mode. Use '\(S3AutoPingItems.Expression.Kind.default.UIDescription)' by default",
        required: true,
        choices: S3AutoPingItems.Expression.Kind.allCases.map {
            .init(name: $0.UIDescription, value: .string($0.rawValue))
        }
    )
}

enum HelpSubCommand: String, CaseIterable {
    case get, add, remove

    var description: String {
        switch self {
        case .get:
            return "Get a help-text"
        case .add:
            return "Add a new help-text"
        case .remove:
            return "Remove a help-text"
        }
    }

    var options: [ApplicationCommand.Option] {
        switch self {
        case .get, .remove:
            return [.init(
                type: .string,
                name: "name",
                description: "The name of the command",
                required: true,
                autocomplete: true
            )]
        case .add:
            return []
        }
    }
}
