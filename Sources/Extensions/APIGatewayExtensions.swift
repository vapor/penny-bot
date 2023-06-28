import AWSLambdaEvents
import Crypto
import Foundation

private let jsonDecoder = JSONDecoder()
private let jsonEncoder = JSONEncoder()

extension APIGatewayV2Request {
    
    public func decode<D: Decodable>(as type: D.Type = D.self) throws -> D {
        guard let body = self.body else {
            throw APIError.invalidRequest
        }
        let data = Data(body.utf8)
        return try jsonDecoder.decode(D.self, from: data)
    }
}

extension APIGatewayV2Response {
    public init(status: HTTPResponseStatus, content: some Encodable) {
        do {
            let data = try jsonEncoder.encode(content)
            let string = String(data: data, encoding: .utf8)
            self.init(statusCode: status, body: string)
        } catch {
            if let data = try? jsonEncoder.encode(content) {
                let string = String(data: data, encoding: .utf8)
                self.init(statusCode: .failedDependency, body: string)
            } else {
                self.init(statusCode: .failedDependency, body: "Plain Error: \(error)")
            }
        }
    }
}

public struct GatewayFailure: Encodable {
    var reason: String
    
    public init(reason: String) {
        self.reason = reason
    }
}

public enum APIError: Error {
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
}
