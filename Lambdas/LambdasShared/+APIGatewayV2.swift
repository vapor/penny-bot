import AWSLambdaEvents
import Crypto

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private let iso8601jsonDecoder: JSONDecoder = {
    var decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

extension APIGatewayV2Request {
    package func decodeWithISO8601<D: Decodable>(as type: D.Type = D.self) throws -> D {
        guard let body = self.body else {
            throw APIGatewayErrors.emptyBody(self)
        }
        let data = Data(body.utf8)
        return try iso8601jsonDecoder.decode(D.self, from: data)
    }
}

enum APIGatewayErrors: Error, CustomStringConvertible {
    case emptyBody(APIGatewayV2Request)

    var description: String {
        switch self {
        case let .emptyBody(request):
            return "emptyBody(\(request))"
        }
    }
}
