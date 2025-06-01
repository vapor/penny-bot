import AWSLambdaEvents
import AWSLambdaRuntime
import AsyncHTTPClient
import HTTPTypes
import LambdasShared
import Models
import Shared
import SotoCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@main
@dynamicMemberLookup
struct AutoPingsHandler {
    struct SharedContext {
        let awsClient: AWSClient
    }

    subscript<T>(dynamicMember keyPath: KeyPath<SharedContext, T>) -> T {
        sharedContext[keyPath: keyPath]
    }

    let sharedContext: SharedContext
    let pingsRepo: S3AutoPingsRepository

    static func main() async throws {
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(Lambda.defaultEventLoop),
            configuration: .forPenny
        )
        let awsClient = AWSClient(httpClient: httpClient)
        let sharedContext = SharedContext(awsClient: awsClient)
        try await LambdaRuntime { (event: APIGatewayV2Request, context: LambdaContext) in
            let handler = AutoPingsHandler(context: context, sharedContext: sharedContext)
            return await handler.handle(event)
        }.run()
    }

    init(context: LambdaContext, sharedContext: SharedContext) {
        self.sharedContext = sharedContext
        self.pingsRepo = S3AutoPingsRepository(awsClient: sharedContext.awsClient, logger: context.logger)
    }

    func handle(_ event: APIGatewayV2Request) async -> APIGatewayV2Response {
        let newItems: S3AutoPingItems
        if event.rawPath.hasSuffix("all") {
            do {
                newItems = try await pingsRepo.getAll()
            } catch {
                return APIGatewayV2Response(
                    status: .expectationFailed,
                    content: GatewayFailure(
                        reason: "Error when getting the full list: \(error)"
                    )
                )
            }
        } else if event.rawPath.hasSuffix("users") {
            switch event.context.http.method {
            case .put:
                do {
                    let request = try event.decode(as: AutoPingsRequest.self)
                    newItems = try await pingsRepo.insert(
                        expressions: request.expressions,
                        forDiscordID: request.discordID
                    )
                } catch {
                    return APIGatewayV2Response(
                        status: .expectationFailed,
                        content: GatewayFailure(
                            reason: "Error when adding texts for user: \(error)"
                        )
                    )
                }
            case .delete:
                do {
                    let request = try event.decode(as: AutoPingsRequest.self)
                    newItems = try await pingsRepo.remove(
                        expressions: request.expressions,
                        forDiscordID: request.discordID
                    )
                } catch {
                    return APIGatewayV2Response(
                        status: .expectationFailed,
                        content: GatewayFailure(
                            reason: "Error when removing texts for user: \(error)"
                        )
                    )
                }
            default:
                return APIGatewayV2Response(
                    status: .badRequest,
                    content: GatewayFailure(
                        reason: "Unexpected method: \(event.context.http.method)"
                    )
                )
            }
        } else {
            return APIGatewayV2Response(
                status: .badRequest,
                content: GatewayFailure(
                    reason: "Unexpected path parameter: \(event.context.http.path)"
                )
            )
        }

        return APIGatewayV2Response(status: .ok, content: newItems)
    }
}
