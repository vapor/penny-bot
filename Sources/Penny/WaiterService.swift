import Logging
import ServiceLifecycle
import Shared

struct WaiterService<UnderlyingService: Service>: Service {
    private let underlying: UnderlyingService
    private let logger: Logger
    private let canRun: @Sendable () async -> Void

    init(
        underlyingService: UnderlyingService,
        logger: Logger = Logger(label: _typeName(Self.self)),
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
        var logger = logger
        logger[metadataKey: "underlyingServiceType"] = .string(_typeName(UnderlyingService.self))
        self.logger = logger
    }

    func run() async throws {
        defer {
            self.logger.debug("Underlying service exited")
        }

        self.logger.trace("Will wait until we can run the underlying service")
        await self.canRun()

        self.logger.debug("Will run the underlying service")
        try await self.underlying.run()
    }
}
