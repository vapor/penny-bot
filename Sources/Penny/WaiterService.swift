import ServiceLifecycle
import Shared

struct WaiterService<UnderlyingService: Service>: Service {
    private let underlying: UnderlyingService
    private let canRun: @Sendable () async -> Void

    init(
        underlyingService: UnderlyingService,
        processingOn backgroundProcessor: BackgroundProcessor,
        passingContinuationWith passContinuation: @Sendable @escaping (CheckedContinuation<Void, Never>) async -> Void
    ) {
        self.underlying = underlyingService
        self.canRun = {
            await withCheckedContinuation { cont in
                backgroundProcessor.process {
                    await passContinuation(cont)
                }
            }
        }
    }

    func run() async throws {
        await self.canRun()
        try await self.underlying.run()
    }
}
