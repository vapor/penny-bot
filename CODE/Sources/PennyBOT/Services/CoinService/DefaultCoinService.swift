import Foundation
import AsyncHTTPClient
import Logging
import PennyModels

struct DefaultCoinService: CoinService {
    let httpClient: HTTPClient
    let logger = Logger(label: "DefaultCoinService")
    
    func postCoin(with coinRequest: CoinRequest) async throws -> CoinResponse {
        var request = HTTPClientRequest(url: "\(Constants.apiBaseUrl!)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try JSONEncoder().encode(coinRequest)
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
        
        let body = try await response.body.collect(upTo: 1 << 32)
        
        return try JSONDecoder().decode(CoinResponse.self, from: body)
    }
}
