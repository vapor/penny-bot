import AsyncHTTPClient
import DiscordModels
import Models

@testable import Penny

public struct FakePingsService: AutoPingsService {

    public init() {}

    private let all = S3AutoPingItems(items: [
        .matches("mongodb driver"): ["432065887202181142", "950695294906007573"],
        .matches("vapor"): ["432065887202181142"],
        .matches("penny"): ["950695294906007573"],
        .matches("discord"): ["432065887202181142"],
        .matches("discord-kit"): ["432065887202181142"],
        .matches("blog"): ["432065887202181142"],
        .contains("godb dr"): ["950695294906007573"],
        .contains("cord"): ["432065887202181142"],
    ])

    public func exists(
        expression: Expression,
        forDiscordID id: UserSnowflake
    ) async throws -> Bool {
        false
    }

    public func insert(
        _ expressions: [Expression],
        forDiscordID id: UserSnowflake
    ) async throws {}

    public func remove(
        _ expressions: [Expression],
        forDiscordID id: UserSnowflake
    ) async throws {}

    public func get(discordID id: UserSnowflake) async throws -> [Expression] {
        self.all.items.filter({ $0.value.contains(id) }).map(\.key)
    }

    public func getExpression(hash: Int) async throws -> Expression? {
        self.all.items.first(where: { $0.key.hashValue == hash })?.key
    }

    public func getAll() async throws -> S3AutoPingItems {
        self.all
    }
}
