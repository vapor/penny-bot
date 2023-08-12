import DiscordBM
import SotoCore
import AsyncHTTPClient
import NIOCore

protocol MainService: Sendable {
    func bootstrapLoggingSystem(httpClient: HTTPClient) async throws
    func makeBot(
        eventLoopGroup: any EventLoopGroup,
        httpClient: HTTPClient
    ) async throws -> any GatewayManager
    func makeCache(bot: any GatewayManager) async throws -> DiscordCache
    func beforeConnectCall(
        bot: any GatewayManager,
        cache: DiscordCache,
        httpClient: HTTPClient,
        awsClient: AWSClient
    ) async throws -> HandlerContext
    func afterConnectCall(context: HandlerContext) async throws
}
