import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation

struct Coin: Codable {
    let value: Int
    let receiver: String
}

struct Response: Codable {
    let body: String
}

// in this example we are receiving and responding with codables. Request and Response above are examples of how to use
// codables to model your request and response objects
@main
struct AddCoins: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    init(context: Lambda.InitializationContext) async throws {
        // setup your resources that you want to reuse for every invocation here.
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        // as an example, respond with the input event's reversed body
//        Response(body: "\(event.receiver) now has \(event.value) coins")
        print(event.context.http.method)
        print(event.context.http.path)
        
//        guard event.context.http.method == .POST, event.context.http.path == "/hello" else {
//            return APIGatewayV2Response(statusCode: .notFound)
//        }
        
        
        
        let response: APIGatewayV2Response
        
        switch (event.context.http.path, event.context.http.method) {
        case ("/hello", .GET):
            response = APIGatewayV2Response(statusCode: .ok, body: "This is an AWS Lambda response made in swift")
        case("/hello", .POST):
            do {
                let product: Coin = try event.bodyObject()
                response = APIGatewayV2Response(statusCode: .ok, body: "\(product.receiver) has \(product.value) coins")
            }
            catch {
                let error = APIError.invalidRequest
                response = APIGatewayV2Response(statusCode: .badRequest, body: String(describing: error))
            }
        default:
            response = APIGatewayV2Response(statusCode: .notFound)
        }
        
        return response
    }
}

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
