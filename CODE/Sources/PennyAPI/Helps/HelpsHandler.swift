import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import PennyModels
import PennyRepositories
import PennyExtensions
import NIOConcurrencyHelpers

@main
struct HelpsHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response

    let awsClient: AWSClient
    let helpsRepo: any HelpsRepository

    init(context: LambdaInitializationContext) async {
        let awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop)
        )
        self.awsClient = awsClient
        self.helpsRepo = RepositoryFactory.makeHelpsRepository((awsClient, context.logger))
    }

    func handle(
        _ event: APIGatewayV2Request,
        context: LambdaContext
    ) async -> APIGatewayV2Response {
        let request: HelpsRequest
        do {
            request = try event.bodyObject()
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
                newItems = try await helpsRepo.getAll()
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
                newItems = try await helpsRepo.insert(name: name, value: value)
            } catch {
                return APIGatewayV2Response(
                    status: .expectationFailed,
                    content: GatewayFailure(
                        reason: "Error when adding help text: \(error)"
                    )
                )
            }
        case let .remove(name):
            do {
                newItems = try await helpsRepo.remove(name: name)
            } catch {
                return APIGatewayV2Response(
                    status: .expectationFailed,
                    content: GatewayFailure(
                        reason: "Error when removing help text: \(error)"
                    )
                )
            }
        }
        return APIGatewayV2Response(status: .ok, content: newItems)
    }
}
