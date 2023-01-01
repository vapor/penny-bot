import Foundation
import DiscordBM

enum Constants {
    static let internalChannelId = "441327731486097429"
    static let botToken: String! = ProcessInfo.processInfo.environment["BOT_TOKEN"]
    static var botId: String! = ProcessInfo.processInfo.environment["BOT_APP_ID"]
    static var coinServiceBaseUrl: String! = ProcessInfo.processInfo.environment["API_BASE_URL"]
    /// Vapor's custom coin emoji in Discord's format.
    static let vaporCoinEmoji = DiscordUtils.customEmoji(name: "coin", id: "473588485962596352")
}
