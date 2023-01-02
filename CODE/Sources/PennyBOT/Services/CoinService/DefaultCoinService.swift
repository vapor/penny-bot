import Foundation
import AsyncHTTPClient
import Logging
import PennyModels

struct DefaultCoinService: CoinService {
    let httpClient: HTTPClient
    let logger: Logger
    
    func postCoin(with coinRequest: CoinRequest.AddCoin) async throws -> CoinResponse {
        var request = HTTPClientRequest(url: "\(Constants.coinServiceBaseUrl!)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try JSONEncoder().encode(CoinRequest.addCoin(coinRequest))
        request.body = .bytes(data)
        let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
        logger.trace("HTTP head \(response)")
        
        guard (200..<300).contains(response.status.code) else {
            logger.error("Post-coin failed. Response: \(response)")
            throw ServiceError.badStatus
        }
        
        let body = try await response.body.collect(upTo: 1024 * 1024)
        
        return try JSONDecoder().decode(CoinResponse.self, from: body)
    }
    
    func getCoinCount(of user: String) async throws -> Int {
        var request = HTTPClientRequest(url: "\(Constants.coinServiceBaseUrl!)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try JSONEncoder().encode(CoinRequest.getCoinCount(user: user))
        request.body = .bytes(data)
        let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
        logger.trace("HTTP head \(response)")
        
        guard (200..<300).contains(response.status.code) else {
            logger.error("Get-coin-count failed. Response: \(response)")
            throw ServiceError.badStatus
        }
        
        let body = try await response.body.collect(upTo: 1024 * 1024)
        
        return try JSONDecoder().decode(Int.self, from: body)
    }
}
