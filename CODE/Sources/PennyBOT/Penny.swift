import Backtrace
import ServiceLifecycle
import Logging

@main
struct Penny {
    static func main() async throws {
        Backtrace.install()
        let group = ServiceGroup(
            services: [MainService()],
            configuration: .init(gracefulShutdownSignals: [.sigterm, .sigint]),
            logger: Logger(label: "ServiceGroup")
        )
        try await group.run()
    }
}
