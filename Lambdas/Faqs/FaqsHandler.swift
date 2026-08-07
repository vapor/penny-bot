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
struct FaqsHandler {
    struct SharedContext {
        let awsClient: AWSClient
    }

    subscript<T>(dynamicMember keyPath: KeyPath<SharedContext, T>) -> T {
        sharedContext[keyPath: keyPath]
    }

    let sharedContext: SharedContext
    let faqsRepo: S3FaqsRepository

    static func main() async throws {
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(Lambda.defaultEventLoop),
            configuration: .forPenny
        )
        let awsClient = AWSClient(httpClient: httpClient)
        let sharedContext = SharedContext(awsClient: awsClient)
        try await LambdaRuntime { (event: FaqsLambdaRequest, context: LambdaContext) in
            let handler = FaqsHandler(context: context, sharedContext: sharedContext)
            return await handler.handle(event)
        }.run()
    }

    init(context: LambdaContext, sharedContext: SharedContext) {
        self.sharedContext = sharedContext
        self.faqsRepo = S3FaqsRepository(awsClient: sharedContext.awsClient, logger: context.logger)
    }

    func handle(_ event: FaqsLambdaRequest) async -> LambdaResult<[String: String]> {
        do {
            switch event {
            case .all:
                return .success(try await faqsRepo.getAll())
            case let .add(name, value):
                return .success(try await faqsRepo.insert(name: name, value: value))
            case let .remove(name):
                return .success(try await faqsRepo.remove(name: name))
            }
        } catch {
            return .failure(reason: "Error when handling faqs request \(event): \(error)")
        }
    }
}
