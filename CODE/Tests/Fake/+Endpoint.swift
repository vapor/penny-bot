@testable import DiscordBM

extension Endpoint {
    var testingKey: String {
        self.httpMethod.rawValue + "/" + self.urlSuffix
    }
}
