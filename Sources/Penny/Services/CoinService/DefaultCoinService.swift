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

    func initialize(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }
    
    func postCoin(with coinRequest: CoinRequest.AddCoin) async throws -> CoinResponse {
        var request = HTTPClientRequest(url: "\(Constants.apiBaseUrl!)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try encoder.encode(CoinRequest.addCoin(coinRequest))
        request.body = .bytes(data)
        let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
        logger.trace("Received HTTP Head", metadata: ["response": "\(response)"])
        
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
        logger.trace("Received HTTP Head", metadata: ["response": "\(response)"])
        
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
        
        return try decoder.decode(Int.self, from: body)
    }
}
