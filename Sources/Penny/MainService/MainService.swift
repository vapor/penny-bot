import AsyncHTTPClient
import DiscordBM
import NIOCore
import SotoCore

protocol MainService: Sendable {
    func bootstrapLoggingSystem(httpClient: HTTPClient) async throws
    func makeBot(httpClient: HTTPClient) async throws -> any GatewayManager
    func makeCache(bot: any GatewayManager) async throws -> DiscordCache
    func beforeConnectCall(
        bot: any GatewayManager,
        cache: DiscordCache,
        httpClient: HTTPClient,
        awsClient: AWSClient
    ) async throws -> HandlerContext
    func runServices(context: HandlerContext) async throws
}
