import DiscordBM
import SotoCore
import AsyncHTTPClient
import NIOCore

protocol MainService: Sendable {
    func bootstrapLoggingSystem() async throws
    func makeBot() async throws -> any GatewayManager
    func makeCache(bot: any GatewayManager) async throws -> DiscordCache
    func beforeConnectCall(
        bot: any GatewayManager,
        cache: DiscordCache
    ) async throws -> HandlerContext
    func afterConnectCall(context: HandlerContext) async throws
}
