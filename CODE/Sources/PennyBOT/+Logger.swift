import AsyncHTTPClient
import DiscordBM
import NIOHTTP1
import NIOCore
import Logging

protocol LoggableHTTPResponse {
    var body: ByteBuffer? { get }
    var status: HTTPResponseStatus { get }
}

extension HTTPClient.Response: LoggableHTTPResponse { }
extension DiscordHTTPResponse: LoggableHTTPResponse { }
extension DiscordClientResponse: LoggableHTTPResponse {
    var body: ByteBuffer? { self.httpResponse.body }
    var status: HTTPResponseStatus { self.httpResponse.status }
}

extension Logger {
    func report(_ message: @autoclosure () -> Logger.Message,
                response: @autoclosure () -> LoggableHTTPResponse?,
                metadata: @autoclosure () -> Logger.Metadata? = nil,
                source: @autoclosure () -> String? = nil,
                file: String = #fileID, function: String = #function, line: UInt = #line) {
        let response = response()
        let metadata = metadata() ?? .init()
        self.log(
            level: .error,
            message(),
            metadata: [
                "status": "\(String(describing: response?.status))",
                "body": "\(String(buffer: response?.body ?? .init()))",
            ].merging(metadata, uniquingKeysWith: { a, _ in a }),
            source: source(), file: file, function: function, line: line)
        self.log(
            level: .debug,
            message(),
            metadata: [
                "response": "\(String(describing: response))",
            ].merging(metadata, uniquingKeysWith: { a, _ in a }),
            source: source(), file: file, function: function, line: line)
    }
}
