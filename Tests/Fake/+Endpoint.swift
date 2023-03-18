@testable import DiscordHTTP

extension Endpoint {
    var testingKey: String {
        self.httpMethod.rawValue + "/" + self.urlSuffix
    }
}
