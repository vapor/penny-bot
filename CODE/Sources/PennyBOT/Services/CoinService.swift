import Foundation
import AsyncHTTPClient
import PennyModels
import Vapor
//import PennyShared

public struct CoinService {
    
    func postCoin(with coinRequest: CoinRequest) async throws -> String {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        let logger = Logger(label: "CoinService")
        
        do {
            let BASE_URL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            logger.warning("\(BASE_URL)")
            var request = HTTPClientRequest(url: "\(BASE_URL ?? "")/coin")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .bytes(Data(try! JSONEncoder().encode(coinRequest)))
            
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            print("HTTP head", response)
            let body = try await response.body.collect(upTo: 1024 * 1024)
            
            let reply = String(buffer: body)
            try await httpClient.shutdown()
            return reply
            
        } catch {
            try await httpClient.shutdown()
            return "request failed: \(error)"
        }
    }
    
    func testLambdaGet() async throws -> String {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        
        do {
            let BASE_URL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            
            var request = HTTPClientRequest(url: "\(BASE_URL ?? "")/coin")
            request.method = .GET
            request.headers.add(name: "Content-Type", value: "application/json")
                        
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            print("HTTP head", response)
            
            let body = try await response.body.collect(upTo: 1024 * 1024)
            
            let message = String(buffer: body)
            
            try await httpClient.shutdown()
            return message
            
        } catch {
            try await httpClient.shutdown()
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
