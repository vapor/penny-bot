package import AWSLambdaRuntime
import NIOCore
package import NewCodable

extension LambdaRuntime where Handler == StreamingClosureHandler {
    package convenience init<Event: JSONDecodable & Sendable, Output: JSONEncodable & Sendable>(
        body: @Sendable @escaping (Event, LambdaContext) async throws -> Output
    ) {
        self.init { event, responseWriter, context in
            let decodedEvent = try NewJSONDecoder().decode(Event.self, from: event.readableBytesSpan)
            let output = try await body(decodedEvent, context)
            let response = try NewJSONEncoder().encode(output) { bytes in
                var buffer = ByteBuffer()
                buffer.writeBytes(bytes)
                return buffer
            }
            try await responseWriter.writeAndFinish(response)
        }
    }
}
