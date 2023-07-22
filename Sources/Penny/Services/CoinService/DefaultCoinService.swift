import Foundation
import AsyncHTTPClient
import Logging
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
    
    func postCoin(with coinRequest: CoinRequest.AddCoin) async throws -> CoinResponse {
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
    
    func getCoinCount(of user: String) async throws -> Int {
        var request = HTTPClientRequest(url: "\(Constants.apiBaseUrl!)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try encoder.encode(CoinRequest.getCoinCount(user: user))
        request.body = .bytes(data)
        let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
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
        
        return try decoder.decode(Int.self, from: body)
    }

    func getGitHubID(of user: String) async throws -> GitHubUserResponse {
        var request = HTTPClientRequest(url: "\(Constants.apiBaseUrl!)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try encoder.encode(CoinRequest.getGitHubID(user: user))
        request.body = .bytes(data)
        let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
        logger.trace("Received HTTP response", metadata: ["response": "\(response)"])

        guard (200..<300).contains(response.status.code) else {
            let collected = try? await response.body.collect(upTo: 1 << 16)
            let body = collected.map { String(buffer: $0) } ?? "nil"
            logger.error("Get-GitHub-id failed", metadata: [
                "status": "\(response.status)",
                "headers": "\(response.headers)",
                "body": "\(body)",
            ])
            throw ServiceError.badStatus(response.status)
        }

        let body = try await response.body.collect(upTo: 1 << 22)

        let decoded = try decoder.decode(GitHubIDResponse.self, from: body)
        switch decoded {
        case .notLinked:
            return .notLinked
        case .id(let id):
            var request = HTTPClientRequest(url: "https://api.github.com/user/\(id)")
            request.headers = [
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "Penny - DiscordPart - 1.0.0 (https://github.com/vapor/penny-bot)"
            ]

            let response = try await httpClient.execute(request, timeout: .seconds(5))
            let body = try await response.body.collect(upTo: 1 << 22)

            logger.debug("Got user response from id", metadata: [
                "status": .stringConvertible(response.status),
                "headers": .stringConvertible(response.headers),
                "body": .string(String(buffer: body)),
                "id": .string(id)
            ])

            let user = try decoder.decode(User.self, from: body)

            return .userName(user.login)
        }
    }
}

private struct User: Codable {
    let login: String
}
