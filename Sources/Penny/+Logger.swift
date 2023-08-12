import AsyncHTTPClient
import DiscordBM
import Logging
import NIOCore
import NIOHTTP1

protocol LoggableHTTPResponse {
    var body: ByteBuffer? { get }
    var status: HTTPResponseStatus { get }
}

extension HTTPClient.Response: LoggableHTTPResponse {}
extension DiscordHTTPResponse: LoggableHTTPResponse {}
extension DiscordClientResponse: LoggableHTTPResponse {
    var body: ByteBuffer? { self.httpResponse.body }
    var status: HTTPResponseStatus { self.httpResponse.status }
}

extension Logger {
    func report(
        _ message: @autoclosure () -> Logger.Message,
        response: (any LoggableHTTPResponse)?,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        let message = message()
        let metadata = metadata() ?? .init()
        let source = source()
        self.log(
            level: .error,
            message,
            metadata: [
                "_status": "\(String(describing: response?.status))",
                "_body": "\(String(buffer: response?.body ?? .init()))",
            ].merging(metadata, uniquingKeysWith: { a, _ in a }),
            source: source,
            file: file,
            function: function,
            line: line
        )
        self.log(
            level: .debug,
            message,
            metadata: [
                "_response": "\(String(describing: response))"
            ].merging(metadata, uniquingKeysWith: { a, _ in a }),
            source: source,
            file: file,
            function: function,
            line: line
        )
    }

    func report(
        _ message: @autoclosure () -> Logger.Message,
        error: any Error,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        let message = message()
        var metadata = metadata() ?? .init()
        let source = source()

        var loggable: (any LoggableHTTPResponse)?

        if let error = error as? any LoggableHTTPResponse {
            loggable = error
        } else if let error = error as? DiscordHTTPError {
            switch error {
            case .badStatusCode(let response):
                loggable = response
                metadata["_tag"] = "bad-status-code"
            case .emptyBody(let response):
                loggable = response
                metadata["_tag"] = "empty-body"
            default: break
            }
        }

        if let loggable {
            self.report(
                message,
                response: loggable,
                metadata: metadata,
                source: source,
                file: file,
                function: function,
                line: line
            )
        } else {
            metadata["_error"] = "\(error)"
            self.error(message, metadata: metadata, source: source, file: file, function: function, line: line)
        }
    }
}
