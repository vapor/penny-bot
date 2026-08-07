import AsyncHTTPClient
import DiscordModels
/// Import full foundation even on linux for `trimmingCharacters`, for now.
import Foundation
import Logging
import Models
import NIOCore
import NIOFoundationCompat
import NIOHTTP1

struct DefaultUsersService: UsersService {
    let httpClient: HTTPClient
    let invoker: LambdaInvoker
    let logger = Logger(label: "DefaultUsersService")

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    init(httpClient: HTTPClient, invoker: LambdaInvoker) {
        self.httpClient = httpClient
        self.invoker = invoker
    }

    private func getOrCreateUser(discordID: UserSnowflake) async throws -> DynamoDBUser {
        let response = try await self.invoker.invokeUsersLambda(.getOrCreateUser(discordID: discordID))
        guard case let .user(user) = response else {
            throw ServiceError.unexpectedUsersLambdaResponse(response)
        }
        return user
    }

    func getUser(githubID: String) async throws -> DynamoDBUser? {
        let response = try await self.invoker.invokeUsersLambda(.getUser(githubID: githubID))
        guard case let .userIfFound(user) = response else {
            throw ServiceError.unexpectedUsersLambdaResponse(response)
        }
        return user
    }

    func postCoin(with coinRequest: UsersLambdaRequest.CoinEntryRequest) async throws -> CoinResponse {
        let response = try await self.invoker.invokeUsersLambda(.addCoin(coinRequest))
        guard case let .coinAdded(coinResponse) = response else {
            throw ServiceError.unexpectedUsersLambdaResponse(response)
        }
        return coinResponse
    }

    func getCoinCount(of discordID: UserSnowflake) async throws -> Int {
        try await self.getOrCreateUser(discordID: discordID).coinCount
    }

    func linkGitHubID(discordID: UserSnowflake, toGitHubID githubID: String) async throws {
        _ = try await self.invoker.invokeUsersLambda(.linkGitHubID(discordID: discordID, toGitHubID: githubID))
    }

    func unlinkGitHubID(discordID: UserSnowflake) async throws {
        _ = try await self.invoker.invokeUsersLambda(.unlinkGitHubID(discordID: discordID))
    }

    func getGitHubName(of discordID: UserSnowflake) async throws -> GitHubUserResponse {
        let user = try await self.getOrCreateUser(discordID: discordID)

        guard let id = user.githubID,
            !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .notLinked
        }

        let encodedID = id.urlPathEncoded()
        let url = "https://api.github.com/user/\(encodedID)"
        logger.debug(
            "Will make a request to get GitHub user name",
            metadata: [
                "user": "\(user)",
                "url": .string(url),
            ]
        )
        var request = HTTPClientRequest(url: url)
        request.headers = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "Penny/1.0.0 (https://github.com/vapor/penny-bot)",
        ]

        let response = try await httpClient.execute(request, timeout: .seconds(5))
        let body = try await response.body.collect(upTo: 1 << 22)
        /// 4 MiB

        logger.debug(
            "Got user response from id",
            metadata: [
                "status": .stringConvertible(response.status),
                "headers": .stringConvertible(response.headers),
                "body": .string(String(buffer: body)),
                "id": .string(id),
            ]
        )

        let githubUser = try decoder.decode(User.self, from: body)

        return .userName(githubUser.login)
    }
}

private struct User: Codable {
    let login: String
}
