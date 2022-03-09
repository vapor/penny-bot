import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation

struct Response: Codable {
    let body: String
}

@main
struct AddCoins: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    init(context: Lambda.InitializationContext) async throws {
        // setup your resources that you want to reuse for every invocation here.
    }

    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
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

public enum APIError: Error{
    case invalidItem
    case tableNameNotFound
    case invalidRequest
    case invalidHandler
}
