import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import Models
import Extensions
import NIOConcurrencyHelpers

@main
struct GHHooksHandler: LambdaHandler {
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

        #warning("fix return")
        return APIGatewayV2Response(
            status: .badRequest,
            content: GatewayFailure(reason: "Unimplemented")
        )
    }
}
