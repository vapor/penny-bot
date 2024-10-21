import Logging
import ServiceLifecycle
import Shared

/// A service that waits until `canRun` is over, then runs the underlying service.
struct WaiterService<UnderlyingService: Service>: Service {
    private let underlying: UnderlyingService
    private let logger: Logger
    private let canRun: @Sendable () async -> Void

    /// - Parameters:
    ///   - underlyingService: The underlying service to be run after the continuation is resolved.
    ///   - logger: A logger to log with.
    ///   - backgroundProcessor: To process the continuation with.
    ///   - passContinuation: Passes continuation using this closure to any other service you'd like.
    ///   Then the other service is responsible for correctly and timely resolving the continuation.
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
