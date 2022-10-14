import Foundation
import AsyncHTTPClient
import PennyModels
import Logging

struct CoinService {
    
    enum ServiceError: Error {
        case badStatus
    }
    
    let logger: Logger
    let httpClient: HTTPClient
    
    func postCoin(with coinRequest: CoinRequest) async throws -> CoinResponse {
        var request = HTTPClientRequest(url: "\(Constants.coinServiceBaseUrl)/coin")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        let data = try JSONEncoder().encode(coinRequest)
        request.body = .bytes(data)
        #warning("Need to mock responses here too")
        let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
        logger.trace("HTTP head \(response)")
        
        guard (200..<300).contains(response.status.code) else {
            logger.error("Post-coin failed. Response: \(response)")
            throw ServiceError.badStatus
        }
        
        let body = try await response.body.collect(upTo: 1024 * 1024)
        
        return try JSONDecoder().decode(CoinResponse.self, from: body)
    }
    
    func testLambdaGet() async throws -> String {
        
        do {
            let BASE_URL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            
            var request = HTTPClientRequest(url: "\(BASE_URL ?? "")/coin")
            request.method = .GET
            request.headers.add(name: "Content-Type", value: "application/json")
                        
            let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
            logger.trace("HTTP head \(response)")
            
            let body = try await response.body.collect(upTo: 1024 * 1024)
            
            let message = String(buffer: body)
            return message
            
        } catch {
            return "request failed: \(error)"
        }
    }
    
//    guard let BASE_URL = URL(string: "\(BASE_URL)/hello") else {
//        fatalError("invalid url")
//    }
//    
//    var request = URLRequest(url: url)
//    request.httpMethod = "POST"
//    
//    guard let jsonRequest = try? JSONEncoder().encode(CoinRequest(receiver: "Melissa", value: 5))
}
