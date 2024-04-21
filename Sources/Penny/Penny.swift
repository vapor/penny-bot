import NIOPosix
import AsyncHTTPClient
import SotoS3

@main
struct Penny {
    static func main() async throws {
        try await start(mainService: PennyService())
    }

    static func start(mainService: any MainService) async throws {
        try await mainService.bootstrapLoggingSystem()

        let bot = try await mainService.makeBot()
        let cache = try await mainService.makeCache(bot: bot)

        let context = try await mainService.beforeConnectCall(bot: bot, cache: cache)

        await bot.connect()

        try await mainService.afterConnectCall(context: context)

        for await event in await bot.events {
            EventHandler(event: event, context: context).handle()
        }
    }
}
