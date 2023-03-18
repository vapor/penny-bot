import AWSLambdaEvents
import Crypto
import Foundation

private let jsonDecoder = JSONDecoder()
private let jsonEncoder = JSONEncoder()

extension APIGatewayV2Request {
    public func decode<D: Decodable>(as _: D.Type = D.self) throws -> D {
        guard let body = self.body,
              let dataBody = body.data(using: .utf8)
        else {
            throw APIError.invalidRequest
        }
        return try jsonDecoder.decode(D.self, from: dataBody)
    }
}

extension APIGatewayV2Response {
    public init(status: HTTPResponseStatus, content: some Encodable) {
        do {
            let data = try jsonEncoder.encode(content)
            let string = String(data: data, encoding: .utf8)
            self.init(statusCode: status, body: string)
        } catch {
            if let data = try? JSONEncoder().encode(content) {
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
    case invalidRequest
}
