import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import SotoCore
import PennyModels
import PennyRepositories

struct FailedToShutdownAWSError: Error {
    let message = "Failed to shutdown the AWS Client"
}

#warning("should here be a NIOLock so we make sure every update is done sequentially?!")
//private let autoPingLock = NIOLock() /// need to pull NIO as a dependency :(

struct AutoPingHandler: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let awsClient: AWSClient
    let pingsRepo: any AutoPingsRepository
    
    init(context: LambdaInitializationContext) async throws {
        #warning("might need awsClient, otherwise remove")
        let awsClient = AWSClient(
            httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop)
        )
        // setup your resources that you want to reuse for every invocation here.
        self.awsClient = awsClient
        self.pingsRepo = RepositoryFactory.makeAutoPingsRepository(context.logger)
        context.terminator.register(name: "Shutdown AWS", handler: { eventLoop in
            do {
                try awsClient.syncShutdown()
                return eventLoop.makeSucceededVoidFuture()
            } catch {
                return eventLoop.makeFailedFuture(FailedToShutdownAWSError())
            }
        })
    }
    
    func handle(
        _ event: APIGatewayV2Request,
        context: LambdaContext
    ) async throws -> APIGatewayV2Response {
        let newItems: S3AutoPingItems
        if event.rawPath == "/all" {
            newItems = try await pingsRepo.getAll()
        } else {
            guard event.rawPath.hasPrefix("/"),
                  !event.rawPath.dropFirst().contains("/")
            else {
                return APIGatewayV2Response(statusCode: .badRequest)
            }
            let discordId = String(event.rawPath.dropFirst())
            if discordId.count < 10 {
                return APIGatewayV2Response(statusCode: .badRequest)
            }
            switch event.context.http.method {
            case .PUT:
                let request: AutoPingRequest = try event.bodyObject()
                newItems = try await pingsRepo.insert(
                    expression: .text(request.text),
                    forDiscordID: discordId
                )
            case .DELETE:
                let request: AutoPingRequest = try event.bodyObject()
                newItems = try await pingsRepo.remove(
                    expression: .text(request.text),
                    forDiscordID: discordId
                )
            default:
                return APIGatewayV2Response(statusCode: .badRequest)
            }
        }
        
        let data = try JSONEncoder().encode(newItems)
        let string = String(data: data, encoding: .utf8)
        return APIGatewayV2Response(statusCode: .ok, body: string)
    }
}

