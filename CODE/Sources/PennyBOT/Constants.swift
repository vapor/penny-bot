import Foundation
import DiscordBM

enum Constants {
    static let internalChannelId = "441327731486097429"
    static let botDevUserId = "290483761559240704"
    static var botToken: String! = ProcessInfo.processInfo.environment["BOT_TOKEN"]
    static var botId: String! = ProcessInfo.processInfo.environment["BOT_APP_ID"]
    static var loggingWebhookUrl: String! = ProcessInfo.processInfo.environment["LOGGING_WEBHOOK_URL"]
    static var coinServiceBaseUrl: String! = ProcessInfo.processInfo.environment["API_BASE_URL"]
    /// Vapor's custom coin emoji in Discord's format.
    static let vaporCoinEmoji = DiscordUtils.customEmoji(name: "coin", id: "473588485962596352")
}
