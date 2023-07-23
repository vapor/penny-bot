#if canImport(Darwin)
import Foundation
#else
@preconcurrency import Foundation
#endif
import AsyncHTTPClient
import Logging
import DiscordModels
import Models

actor DefaultCoinService: CoinService {
    var httpClient: HTTPClient!
    let logger = Logger(label: "DefaultCoinService")
    
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    
    static let shared = DefaultCoinService()
    
    private init() { }
    
    func initialize(httpClient: HTTPClient) throws {
        self.httpClient = httpClient
    }

    private func getUser(discordID: UserSnowflake) async throws -> DynamoDBUser {
        var request = HTTPClientRequest(url: "\(Constants.apiBaseUrl!)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")

        let requestContent = CoinRequest.getUser(discordID: discordID)
        let data = try encoder.encode(requestContent)
        request.body = .bytes(data)

        let response = try await httpClient.execute(
            request,
            timeout: .seconds(30),
            logger: self.logger
        )
        logger.trace("Received HTTP response", metadata: ["response": "\(response)"])

        guard (200..<300).contains(response.status.code) else {
            let collected = try? await response.body.collect(upTo: 1 << 16)
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error("Get-coin-count failed", metadata: [
                "status": "\(response.status)",
                "headers": "\(response.headers)",
                "body": "\(body)",
            ])
            throw ServiceError.badStatus(response.status)
        }

        let body = try await response.body.collect(upTo: 1 << 24)

        return try decoder.decode(DynamoDBUser.self, from: body)
    }

    func postCoin(with coinRequest: CoinRequest.DiscordCoinEntry) async throws -> CoinResponse {
        var request = HTTPClientRequest(url: "\(Constants.apiBaseUrl!)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try encoder.encode(CoinRequest.addCoin(coinRequest))
        request.body = .bytes(data)
        let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
        logger.trace("Received HTTP response", metadata: ["response": "\(response)"])
        
        guard (200..<300).contains(response.status.code) else {
            let collected = try? await response.body.collect(upTo: 1 << 16)
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error( "Post-coin failed", metadata: [
                "status": "\(response.status)",
                "headers": "\(response.headers)",
                "body": "\(body)",
            ])
            throw ServiceError.badStatus(response.status)
        }
        
        let body = try await response.body.collect(upTo: 1 << 24)
        
        return try decoder.decode(CoinResponse.self, from: body)
    }

    func getCoinCount(of discordID: UserSnowflake) async throws -> Int {
        try await self.getUser(discordID: discordID).coinCount
    }

    func getGitHubName(of discordID: UserSnowflake) async throws -> GitHubUserResponse {
        let user = try await self.getUser(discordID: discordID)

        guard let id = user.githubID else {
            return .notLinked
        }

        let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let url = "https://api.github.com/user/\(encodedID)"
        logger.debug("Will make a request to get GitHub user name", metadata: [
            "user": "\(user)",
            "url": .string(url),
        ])
        var request = HTTPClientRequest(url: url)
        request.headers = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "Penny/1.0.0 (https://github.com/vapor/penny-bot)"
        ]

        let response = try await httpClient.execute(request, timeout: .seconds(5))
        let body = try await response.body.collect(upTo: 1 << 22)

        logger.debug("Got user response from id", metadata: [
            "status": .stringConvertible(response.status),
            "headers": .stringConvertible(response.headers),
            "body": .string(String(buffer: body)),
            "id": .string(id)
        ])

        let githubUser = try decoder.decode(User.self, from: body)

        return .userName(githubUser.login)
    }
}

private struct User: Codable {
    let login: String
}
