import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import PennyModels
import PennyRepositories
import NIOConcurrencyHelpers

/// So the s3-file-updates happen in a sequential order?
private let autoPingLock = NIOLock()

@main
struct AutoPingsHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let awsClient: AWSClient
    let pingsRepo: any AutoPingsRepository
    
    init(context: LambdaInitializationContext) async throws {
        let awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop)
        )
        self.awsClient = awsClient
        self.pingsRepo = RepositoryFactory.makeAutoPingsRepository((awsClient, context.logger))
        context.terminator.register(name: "Shutdown AWS", handler: { eventLoop in
            eventLoop.makeFutureWithTask {
                try await awsClient.shutdown()
            }
        })
    }
    
    func handle(
        _ event: APIGatewayV2Request,
        context: LambdaContext
    ) async throws -> APIGatewayV2Response {
        autoPingLock.lock()
        defer { autoPingLock.unlock() }
        
        let newItems: S3AutoPingItems
        if event.rawPath.hasSuffix("all") {
            newItems = try await pingsRepo.getAll()
        } else {
            guard let _discordId = event.rawPath.split(separator: "/").last,
                  _discordId.count > 10 else {
                return APIGatewayV2Response(
                    status: .badRequest,
                    content: Failure(reason: "Couldn't find discord id from path: \(event.rawPath.debugDescription)")
                )
            }
            let discordId = String(_discordId)
            switch event.context.http.method {
            case .PUT:
                let request: AutoPingRequest = try event.bodyObject()
                newItems = try await pingsRepo.insert(
                    expressions: request.texts.map { .text($0) },
                    forDiscordID: discordId
                )
            case .DELETE:
                let request: AutoPingRequest = try event.bodyObject()
                newItems = try await pingsRepo.remove(
                    expressions: request.texts.map { .text($0) },
                    forDiscordID: discordId
                )
            default:
                return APIGatewayV2Response(
                    status: .badRequest,
                    content: Failure(reason: "Unexpected method: \(event.context.http.method)")
                )
            }
        }
        
        return APIGatewayV2Response(status: .ok, content: newItems)
    }
}

extension APIGatewayV2Response {
    init(status: HTTPResponseStatus, content: some Encodable) {
        do {
            let data = try JSONEncoder().encode(content)
            let string = String(data: data, encoding: .utf8)
            self.init(statusCode: status, body: string)
        } catch {
            if let data = try? JSONEncoder().encode(content) {
                let string = String(data: data, encoding: .utf8)
                self.init(statusCode: .internalServerError, body: string)
            } else {
                self.init(statusCode: .internalServerError, body: "Plain Error: \(error)")
            }
        }
    }
}

struct Failure: Encodable {
    var reason: String
}
