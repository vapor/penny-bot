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
    let apiBaseURL: String
    let logger = Logger(label: "DefaultUsersService")

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    init(httpClient: HTTPClient, apiBaseURL: String) {
        self.httpClient = httpClient
        self.apiBaseURL = apiBaseURL
    }

    private func getOrCreateUser(discordID: UserSnowflake) async throws -> DynamoDBUser {
        var request = HTTPClientRequest(url: "\(apiBaseURL)/users")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")

        let requestContent = UserRequest.getOrCreateUser(discordID: discordID)
        let data = try encoder.encode(requestContent)
        request.body = .bytes(data)

        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("Received HTTP response", metadata: ["response": "\(response)"])

        let body = try await response.body.collect(upTo: 1 << 24)
        /// 16 MiB

        guard 200..<300 ~= response.status.code else {
            logger.error(
                "Get-coin-count failed",
                metadata: [
                    "status": "\(response.status)",
                    "headers": "\(response.headers)",
                    "body": "\(String(buffer: body))",
                ]
            )
            throw ServiceError.badStatus(response)
        }

        return try decoder.decode(DynamoDBUser.self, from: body)
    }

    func getUser(githubID: String) async throws -> DynamoDBUser? {
        var request = HTTPClientRequest(url: "\(apiBaseURL)/users")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")

        let requestContent = UserRequest.getUser(githubID: githubID)
        let data = try encoder.encode(requestContent)
        request.body = .bytes(data)

        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("Received HTTP response", metadata: ["response": "\(response)"])

        let body = try await response.body.collect(upTo: 1 << 24)
        /// 16 MiB

        guard 200..<300 ~= response.status.code else {
            logger.error(
                "Get-coin-count failed",
                metadata: [
                    "status": "\(response.status)",
                    "headers": "\(response.headers)",
                    "body": "\(String(buffer: body))",
                ]
            )
            throw ServiceError.badStatus(response)
        }

        return try decoder.decode(DynamoDBUser?.self, from: body)
    }

    func postCoin(with coinRequest: UserRequest.CoinEntryRequest) async throws -> CoinResponse {
        var request = HTTPClientRequest(url: "\(apiBaseURL)/users")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")

        let requestContent = UserRequest.addCoin(coinRequest)
        let data = try encoder.encode(requestContent)
        request.body = .bytes(data)

        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("Received HTTP response", metadata: ["response": "\(response)"])

        let body = try await response.body.collect(upTo: 1 << 24)
        /// 16 MiB

        guard 200..<300 ~= response.status.code else {
            logger.error(
                "Post-coin failed",
                metadata: [
                    "status": "\(response.status)",
                    "headers": "\(response.headers)",
                    "body": "\(String(buffer: body))",
                ]
            )
            throw ServiceError.badStatus(response)
        }

        return try decoder.decode(CoinResponse.self, from: body)
    }

    func getCoinCount(of discordID: UserSnowflake) async throws -> Int {
        try await self.getOrCreateUser(discordID: discordID).coinCount
    }

    func linkGitHubID(discordID: UserSnowflake, toGitHubID githubID: String) async throws {
        var request = HTTPClientRequest(url: "\(apiBaseURL)/users")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")

        let requestContent = UserRequest.linkGitHubID(discordID: discordID, toGitHubID: githubID)
        let data = try encoder.encode(requestContent)
        request.body = .bytes(data)

        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("Received HTTP response", metadata: ["response": "\(response)"])

        guard 200..<300 ~= response.status.code else {
            let collected = try? await response.body.collect(upTo: 1 << 16)
            /// 64 KiB
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error(
                "Link-GitHub-id failed",
                metadata: [
                    "status": "\(response.status)",
                    "headers": "\(response.headers)",
                    "body": "\(body)",
                ]
            )
            throw ServiceError.badStatus(response)
        }
    }

    func unlinkGitHubID(discordID: UserSnowflake) async throws {
        var request = HTTPClientRequest(url: "\(apiBaseURL)/users")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")

        let requestContent = UserRequest.unlinkGitHubID(discordID: discordID)
        let data = try encoder.encode(requestContent)
        request.body = .bytes(data)

        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("Received HTTP response", metadata: ["response": "\(response)"])

        guard 200..<300 ~= response.status.code else {
            let collected = try? await response.body.collect(upTo: 1 << 16)
            /// 64 KiB
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error(
                "Unlink-GitHub-id failed",
                metadata: [
                    "status": "\(response.status)",
                    "headers": "\(response.headers)",
                    "body": "\(body)",
                ]
            )
            throw ServiceError.badStatus(response)
        }
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
