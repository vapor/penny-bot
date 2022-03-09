import Foundation
import PennyShared

public struct CoinService {
    private let BASE_URL = ProcessInfo.processInfo.environment["API_BASE_URL"]
    guard let BASE_URL = URL(string: "\(BASE_URL)/hello") else {
        fatalError("invalid url")
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    guard let jsonRequest = try? JSONEncoder().encode(CoinRequest(receiver: "Melissa", value: 5))
}
