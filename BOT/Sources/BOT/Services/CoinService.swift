import Foundation
import AsyncHTTPClient
//import PennyShared

public struct CoinService {
    
    func postCoin(to receiver: String, with value: Int) async throws -> String {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        let coin = CoinReq(value: value, receiver: receiver)
        
        do {
            let BASE_URL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            
            var request = HTTPClientRequest(url: "\(BASE_URL ?? "")/hello")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            
            request.body = .bytes(Data(try JSONEncoder().encode(coin)))
            
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            print("HTTP head", response)
            let body = try await response.body.collect(upTo: 1024 * 1024)
            
            let coin = String(buffer: body)
            try await httpClient.shutdown()
            return coin
            
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
