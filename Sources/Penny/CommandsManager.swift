import DiscordBM
import Logging
import Models

struct CommandsManager {
    let context: HandlerContext

    func registerCommands() async {
        let commands = makeCommands()
        await context.services.discordService.overwriteCommands(commands)
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
    case github
    case autoPings = "auto-pings"
    case faqs
    case autoFaqs = "auto-faqs"
    case howManyCoins = "how-many-coins"
    case howManyCoinsApp = "How Many Coins?"

    var description: String? {
        switch self {
        case .github:
            return "Link your GitHub account to Penny"
        case .autoPings:
            return "Configure Penny to ping you when certain someone uses a word/text"
        case .faqs:
            return "Answers for frequently asked questions"
        case .autoFaqs:
            return "Automatic answers to configured frequently asked questions"
        case .howManyCoins:
            return "See how many coins members have"
        case .howManyCoinsApp:
            return nil
        }
    }

    var options: [ApplicationCommand.Option]? {
        switch self {
        case .github:
            return GitHubSubCommand.allCases.map { subCommand in
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
        case .faqs:
            return FaqsSubCommand.allCases.map { subCommand in
                ApplicationCommand.Option(
                    type: .subCommand,
                    name: subCommand.rawValue,
                    description: subCommand.description,
                    options: subCommand.options
                )
            }
        case .autoFaqs:
            return AutoFaqsSubCommand.allCases.map { subCommand in
                ApplicationCommand.Option(
                    type: .subCommand,
                    name: subCommand.rawValue,
                    description: subCommand.description,
                    options: subCommand.options
                )
            }
        case .howManyCoins:
            return [
                .init(
                    type: .user,
                    name: "member",
                    description: "The member to check their coin count"
                )
            ]
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
        case .github, .autoPings, .faqs, .autoFaqs, .howManyCoins:
            return nil
        }
    }
}

enum GitHubSubCommand: String, CaseIterable {
    case link
    case unlink
    case whoAmI = "who-am-i"

    var description: String {
        switch self {
        case .link:
            return "Link your GitHub account to Penny"
        case .unlink:
            return "Unlink your GitHub account from Penny"
        case .whoAmI:
            return "See what GitHub account is linked to your Discord user"
        }
    }

    var options: [ApplicationCommand.Option] {
        switch self {
        case .link, .unlink, .whoAmI:
            return []
        }
    }
}

enum AutoPingsSubCommand: String, CaseIterable {
    case help
    case add
    case remove
    case bulkRemove = "bulk-remove"
    case list
    case test

    var description: String {
        switch self {
        case .help:
            return "Help about how auto-pings works"
        case .add:
            return "Add multiple expressions to be pinged for (Slack compatible)"
        case .remove:
            return "Remove a ping expression"
        case .bulkRemove:
            return "Remove multiple ping expressions"
        case .list:
            return "See what you'll get pinged for"
        case .test:
            return "Test if a message triggers an auto-ping expression"
        }
    }

    var options: [ApplicationCommand.Option] {
        switch self {
        case .add, .bulkRemove, .test:
            return [Self.expressionModeOption]
        case .remove:
            return [
                .init(
                    type: .string,
                    name: "expression",
                    description: "What expression to remove",
                    required: true,
                    autocomplete: true
                )
            ]
        case .help, .list:
            return []
        }
    }

    private static let expressionModeOption = ApplicationCommand.Option(
        type: .string,
        name: "mode",
        description:
            "The expression mode. Use '\(S3AutoPingItems.Expression.Kind.default.UIDescription)' by default",
        required: true,
        choices: S3AutoPingItems.Expression.Kind.allCases.map {
            .init(name: $0.UIDescription, value: .string($0.rawValue))
        }
    )
}

enum FaqsSubCommand: String, CaseIterable {
    case get, add, edit, rename, remove

    var description: String {
        switch self {
        case .get:
            return "Get a faq"
        case .add:
            return "Add a new faq"
        case .edit:
            return "Edit value of a faq"
        case .rename:
            return "Rename a faq"
        case .remove:
            return "Remove a faq"
        }
    }

    var options: [ApplicationCommand.Option] {
        switch self {
        case .get:
            return [
                .init(
                    type: .string,
                    name: "name",
                    description: "The name of the command",
                    required: true,
                    autocomplete: true
                ),
                .init(
                    type: .boolean,
                    name: "ephemeral",
                    description: "If True, the response will only be visible to you",
                    required: false
                ),
            ]
        case .remove, .edit, .rename:
            return [
                .init(
                    type: .string,
                    name: "name",
                    description: "The name of the command",
                    required: true,
                    autocomplete: true
                )
            ]
        case .add:
            return []
        }
    }
}

enum AutoFaqsSubCommand: String, CaseIterable {
    case get, add, edit, rename, remove

    var description: String {
        switch self {
        case .get:
            return "Manually get an auto-faq"
        case .add:
            return "Add a new auto-faq"
        case .edit:
            return "Edit value of an auto-faq"
        case .rename:
            return "Rename an auto-faq"
        case .remove:
            return "Remove an auto-faq"
        }
    }

    var options: [ApplicationCommand.Option] {
        switch self {
        case .get:
            return [
                .init(
                    type: .string,
                    name: "expression",
                    description: "The expression of the command",
                    required: true,
                    autocomplete: true
                ),
                .init(
                    type: .boolean,
                    name: "ephemeral",
                    description: "If True, the response will only be visible to you",
                    required: false
                ),
            ]
        case .remove, .edit, .rename:
            return [
                .init(
                    type: .string,
                    name: "expression",
                    description: "The matching expression of the answer",
                    required: true,
                    autocomplete: true
                )
            ]
        case .add:
            return []
        }
    }
}
