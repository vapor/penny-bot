import AsyncHTTPClient
import NIO
import Logging
import Shared
import LeafKit

struct GHLeafSource: LeafSource {

    enum Errors: Error, CustomStringConvertible {
        case httpRequestFailed(HTTPClientResponse, body: String)

        var description: String {
            switch self {
            case let .httpRequestFailed(response, body):
                return "httpRequestFailed(\(response), body: \(body))"
            }
        }
    }

    private actor ActorGHLeafSource {
        let path: String
        let httpClient: HTTPClient = .shared
        let logger: Logger
        let queue = SerialProcessor()
        var cache: [String: ByteBuffer] = [:]

        init(
            path: String,
            logger: Logger
        ) {
            self.path = path
            self.logger = logger
        }

        func file(template: String) async throws -> ByteBuffer {
            try await queue.process(queueKey: template) {
                if let existing = await self.getFromCache(key: template) {
                    return existing
                } else {
                    let new = try await pull(template: template)
                    await self.saveToCache(key: template, value: new)
                    return new
                }
            }
        }

        private func pull(template: String) async throws -> ByteBuffer {
            let url = "https://raw.githubusercontent.com/vapor/penny-bot/main/\(path)/\(template)"
            let request = HTTPClientRequest(url: url)
            let response = try await httpClient.execute(request, timeout: .seconds(5))
            let body = try await response.body.collect(upTo: 1 << 22) /// 4 MiB
            guard 200..<300 ~= response.status.code else {
                throw Errors.httpRequestFailed(response, body: String(buffer: body))
            }
            return body
        }

        private func getFromCache(key: String) -> ByteBuffer? {
            self.cache[key]
        }

        private func saveToCache(key: String, value: ByteBuffer) {
            self.cache[key] = value
        }
    }

    private let underlying: ActorGHLeafSource

    init(
        path: String,
        logger: Logger
    ) {
        self.underlying = .init(
            path: path,
            logger: logger
        )
    }

    func file(
        template: String,
        escape: Bool,
        on eventLoop: any EventLoop
    ) throws -> EventLoopFuture<ByteBuffer> {
        eventLoop.makeFutureWithTask {
            try await underlying.file(template: template)
        }
    }
}
