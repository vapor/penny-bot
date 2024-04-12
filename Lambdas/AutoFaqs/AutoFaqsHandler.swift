import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import Models
import LambdasShared

@main
struct AutoFaqsHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let awsClient: AWSClient
    let autoFaqsRepo: S3AutoFaqsRepository

    init(context: LambdaInitializationContext) async {
        self.awsClient = AWSClient()
        self.autoFaqsRepo = S3AutoFaqsRepository(awsClient: awsClient, logger: context.logger)
    }

    func handle(
        _ event: APIGatewayV2Request,
        context: LambdaContext
    ) async -> APIGatewayV2Response {
        let request: AutoFaqsRequest
        do {
            request = try event.decode()
        } catch {
            return APIGatewayV2Response(
                status: .badRequest,
                content: GatewayFailure(reason: "Unexpected body: \(event.body ?? "nil")")
            )
        }
        let newItems: [String: String]
        switch request {
        case .all:
            do {
                newItems = try await autoFaqsRepo.getAll()
            } catch {
                return APIGatewayV2Response(
                    status: .expectationFailed,
                    content: GatewayFailure(
                        reason: "Error when getting the full list: \(error)"
                    )
                )
            }
        case let .add(expression, value):
            do {
                newItems = try await autoFaqsRepo.insert(expression: expression, value: value)
            } catch {
                return APIGatewayV2Response(
                    status: .expectationFailed,
                    content: GatewayFailure(
                        reason: "Error when adding faqs text: \(error)"
                    )
                )
            }
        case let .remove(expression):
            do {
                newItems = try await autoFaqsRepo.remove(expression: expression)
            } catch {
                return APIGatewayV2Response(
                    status: .expectationFailed,
                    content: GatewayFailure(
                        reason: "Error when removing faqs text: \(error)"
                    )
                )
            }
        }
        return APIGatewayV2Response(status: .ok, content: newItems)
    }
}
