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
        try await LambdaRuntime { (event: AutoPingsLambdaRequest, context: LambdaContext) in
            let handler = AutoPingsHandler(context: context, sharedContext: sharedContext)
            return await handler.handle(event)
        }.run()
    }

    init(context: LambdaContext, sharedContext: SharedContext) {
        self.sharedContext = sharedContext
        self.pingsRepo = S3AutoPingsRepository(awsClient: sharedContext.awsClient, logger: context.logger)
    }

    func handle(_ event: AutoPingsLambdaRequest) async -> LambdaResult<S3AutoPingItems> {
        do {
            switch event {
            case .all:
                return .success(try await pingsRepo.getAll())
            case let .insert(request):
                return .success(
                    try await pingsRepo.insert(
                        expressions: request.expressions,
                        forDiscordID: request.discordID
                    )
                )
            case let .remove(request):
                return .success(
                    try await pingsRepo.remove(
                        expressions: request.expressions,
                        forDiscordID: request.discordID
                    )
                )
            }
        } catch {
            return .failure(reason: "Error when handling auto-pings request \(event): \(error)")
        }
    }
}
