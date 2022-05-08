import Foundation
import AsyncHTTPClient
import PennyModels
import Vapor
//import PennyShared

public struct CoinService {
    
    let logger: Logger
    let httpClient: HTTPClient
    
    func postCoin(with coinRequest: CoinRequest) async throws -> String {
        do {
            let BASE_URL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            logger.trace("\(String(describing: BASE_URL))")
            var request = HTTPClientRequest(url: "\(BASE_URL ?? "")/coin")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .bytes(Data(try! JSONEncoder().encode(coinRequest)))
            
            let response = try await httpClient.execute(request, timeout: .seconds(30), logger: self.logger)
            logger.trace("HTTP head \(response)")
            let body = try await response.body.collect(upTo: 1024 * 1024)
            
            let reply = String(buffer: body)
            return reply
            
        } catch {
            return "request failed: \(error)"
        }
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
