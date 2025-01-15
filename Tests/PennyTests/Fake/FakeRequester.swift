import AsyncHTTPClient
import Logging

@testable import DiscordModels
@testable import GHHooksLambda

struct FakeRequester: GenericRequester {
    var httpClient: HTTPClient = .shared
    var logger: Logger = .init(label: "FakeRequester")

    func getDiscordMember(githubID: String) async throws -> GuildMember? {
        switch githubID {
        case "54685446":
            return .init(
                uiName: "MahdiBM",
                uiAvatarURL: nil,
                userId: "290483761559240704",
                roles: []
            )
        case "69189821":
            return .init(
                uiName: "Paul",
                uiAvatarURL: nil,
                userId: "409376125995974666",
                roles: []
            )
        default:
            fatalError("Unhandled githubID: \(githubID)")
        }
    }
}
