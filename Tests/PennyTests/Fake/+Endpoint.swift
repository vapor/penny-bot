import NIOHTTP1

@testable import DiscordHTTP

extension Endpoint {
    var testingKey: String {
        self.httpMethod.rawValue + "-" + self.url
    }
}
