@testable import DiscordClient

extension Endpoint {
    var testingKey: String {
        self.httpMethod.rawValue + "/" + self.urlSuffix
    }
}
