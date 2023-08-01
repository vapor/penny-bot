import AWSLambdaEvents
import Foundation

enum Errors: Error, CustomStringConvertible {
    case httpRequestFailed(response: any Sendable, file: String = #filePath, line: UInt = #line)
    case headerNotFound(name: String, headers: AWSLambdaEvents.HTTPHeaders)
    case envVarNotFound(key: String)
    case multipleErrors([any Error])

    var description: String {
        switch self {
        case let .httpRequestFailed(response, file, line):
            return "httpRequestFailed(response: \(response), file: \(file), line: \(line))"
        case let .headerNotFound(name, headers):
            return "headerNotFound(name: \(name), headers: \(headers))"
        case let .envVarNotFound(key):
            return "envVarNotFound(key: \(key))"
        case let .multipleErrors(errors):
            return "multipleErrors(\(errors.map({ "\($0)" })))"
        }
    }
}
