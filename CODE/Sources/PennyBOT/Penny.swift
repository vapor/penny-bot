import Backtrace
import ServiceLifecycle
import Logging

@main
struct Penny {
    static func main() async throws {
        Backtrace.install()
        /// For now we only have one service,
        /// which means we aren't really taking advantage of what `ServiceGroup` offers.
        let group = ServiceGroup(
            services: [MainService()],
            configuration: .init(gracefulShutdownSignals: [.sigterm, .sigint]),
            logger: Logger(label: "ServiceGroup")
        )
        try await group.run()
    }
}
