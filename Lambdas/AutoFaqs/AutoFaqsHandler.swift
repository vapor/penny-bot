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
struct AutoFaqsHandler {
    struct SharedContext {
        let awsClient: AWSClient
    }

    subscript<T>(dynamicMember keyPath: KeyPath<SharedContext, T>) -> T {
        sharedContext[keyPath: keyPath]
    }

    let sharedContext: SharedContext
    let autoFaqsRepo: S3AutoFaqsRepository

    static func main() async throws {
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(Lambda.defaultEventLoop),
            configuration: .forPenny
        )
        let awsClient = AWSClient(httpClient: httpClient)
        let sharedContext = SharedContext(awsClient: awsClient)
        try await LambdaRuntime { (event: AutoFaqsLambdaRequest, context: LambdaContext) in
            let handler = AutoFaqsHandler(context: context, sharedContext: sharedContext)
            return await handler.handle(event)
        }.run()
    }

    init(context: LambdaContext, sharedContext: SharedContext) {
        self.sharedContext = sharedContext
        self.autoFaqsRepo = S3AutoFaqsRepository(awsClient: sharedContext.awsClient, logger: context.logger)
    }

    func handle(_ event: AutoFaqsLambdaRequest) async -> LambdaResult<[String: String]> {
        do {
            switch event {
            case .all:
                return .success(try await autoFaqsRepo.getAll())
            case let .add(expression, value):
                return .success(try await autoFaqsRepo.insert(expression: expression, value: value))
            case let .remove(expression):
                return .success(try await autoFaqsRepo.remove(expression: expression))
            }
        } catch {
            return .failure(reason: "Error when handling auto-faqs request \(event): \(error)")
        }
    }
}
