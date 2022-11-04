import Foundation

enum Constants {
    static let internalChannelId = "441327731486097429"
    static var botToken: String! = ProcessInfo.processInfo.environment["BOT_TOKEN"]
    static var botId: String! = ProcessInfo.processInfo.environment["BOT_APP_ID"]
    static var coinServiceBaseUrl: String! = ProcessInfo.processInfo.environment["API_BASE_URL"]
}
