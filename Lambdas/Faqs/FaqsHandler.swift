import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import Models
import Extensions

@main
struct FaqsHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let awsClient: AWSClient
    let faqsRepo: S3FaqsRepository

    init(context: LambdaInitializationContext) async {
        let awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop)
        )
        self.awsClient = awsClient
        self.faqsRepo = S3FaqsRepository(awsClient: awsClient, logger: context.logger)
    }

    func handle(
        _ event: APIGatewayV2Request,
        context: LambdaContext
    ) async -> APIGatewayV2Response {
        let request: FaqsRequest
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
                newItems = try await faqsRepo.getAll()
            } catch {
                return APIGatewayV2Response(
                    status: .expectationFailed,
                    content: GatewayFailure(
                        reason: "Error when getting the full list: \(error)"
                    )
                )
            }
        case let .add(name, value):
            do {
                newItems = try await faqsRepo.insert(name: name, value: value)
            } catch {
                return APIGatewayV2Response(
                    status: .expectationFailed,
                    content: GatewayFailure(
                        reason: "Error when adding faqs text: \(error)"
                    )
                )
            }
        case let .remove(name):
            do {
                newItems = try await faqsRepo.remove(name: name)
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
