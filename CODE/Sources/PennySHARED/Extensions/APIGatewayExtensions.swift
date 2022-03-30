import AWSLambdaEvents
import Foundation

extension APIGatewayV2Request {
    static private let decoder = JSONDecoder()
    
    public func bodyObject<T: Codable>() throws -> T {
        guard let body = self.body,
              let dataBody = body.data(using: .utf8)
        else {
            throw APIError.invalidRequest
        }
        return try Self.decoder.decode(T.self, from: dataBody)
    }
}

extension APIGatewayV2Response {
    static private let encoder = JSONEncoder()
    
    public static let defaultHeaders = [
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "OPTIONS,GET,POST,PUT,DELETE",
        "Access-Control-Allow-Credentials": "true",
    ]
    
    public init(with error: Error, statusCode: AWSLambdaEvents.HTTPResponseStatus) {
        self.init(
            statusCode: statusCode,
            headers: APIGatewayV2Response.defaultHeaders,
            body: "{\"message\":\"\(String(describing: error))\"}",
            isBase64Encoded: false
        )
    }
    
    public init<Out: Encodable>(with object: Out, statusCode: AWSLambdaEvents.HTTPResponseStatus) {
        var body: String = "{}"
        if let data = try? Self.encoder.encode(object) {
            body = String(data: data, encoding: .utf8) ?? body
        }
        
        self.init(
            statusCode: statusCode,
            headers: APIGatewayV2Response.defaultHeaders,
            body: body,
            isBase64Encoded: false
        )
    }
}

public enum APIError: Error{
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
}
