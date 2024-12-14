import AWSLambdaEvents
import Crypto
import HTTPTypes

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private let jsonDecoder = JSONDecoder()
private let iso8601jsonDecoder: JSONDecoder = {
    var decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()
private let jsonEncoder = JSONEncoder()

extension APIGatewayV2Request {

    package func decode<D: Decodable>(as type: D.Type = D.self) throws -> D {
        guard let body = self.body else {
            throw APIGatewayErrors.emptyBody(self)
        }
        let data = Data(body.utf8)
        return try jsonDecoder.decode(D.self, from: data)
    }

    package func decodeWithISO8601<D: Decodable>(as type: D.Type = D.self) throws -> D {
        guard let body = self.body else {
            throw APIGatewayErrors.emptyBody(self)
        }
        let data = Data(body.utf8)
        return try iso8601jsonDecoder.decode(D.self, from: data)
    }
}

extension APIGatewayV2Response {
    package init(status: HTTPResponse.Status, content: some Encodable) {
        do {
            let data = try jsonEncoder.encode(content)
            let string = String(data: data, encoding: .utf8)
            self.init(statusCode: status, body: string)
        } catch {
            if let data = try? jsonEncoder.encode(content) {
                let string = String(data: data, encoding: .utf8)
                self.init(statusCode: .preconditionFailed, body: string)
            } else {
                self.init(statusCode: .preconditionFailed, body: "Plain Error: \(error)")
            }
        }
    }
}

package struct GatewayFailure: Encodable {
    var reason: String

    package init(reason: String) {
        self.reason = reason
    }
}

package enum APIGatewayErrors: Error, CustomStringConvertible {
    case emptyBody(APIGatewayV2Request)

    package var description: String {
        switch self {
        case let .emptyBody(request):
            return "emptyBody(\(request))"
        }
    }
}
