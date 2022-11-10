import Foundation

enum Constants {
    static func env(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
    static let internalChannelId = "441327731486097429"
    static var botToken: String! = env("BOT_TOKEN")
    static var botId: String! = env("BOT_APP_ID")
    static var coinServiceBaseUrl: String! = env("API_BASE_URL")
    static var pingServiceBaseUrl: String! = env("PINGS_ API_BASE_URL")
}
