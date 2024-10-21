import ServiceLifecycle

struct WaiterService<UnderlyingService: Service>: Service {
    private let underlying: UnderlyingService
    private let canRun: @Sendable () async -> Void

    init(underlyingService: UnderlyingService, canRun: @escaping @Sendable () async -> Void) {
        self.underlying = underlyingService
        self.canRun = canRun
    }

    func run() async throws {
        await self.canRun()
        try await self.underlying.run()
    }
}
