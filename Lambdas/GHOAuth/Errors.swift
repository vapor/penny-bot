import AWSLambdaEvents
import AsyncHTTPClient

enum Errors: Error, CustomStringConvertible {
    case envVarNotFound(name: String)
    case secretNotFound(arn: String)
    case httpRequestFailed(response: HTTPClientResponse, body: String)
    case invalidPublicKey

    var description: String {
        switch self {
        case let .envVarNotFound(name):
            return "Environment variable not found: \(name)."
        case let .secretNotFound(arn):
            return "Could not find secret with ARN: \(arn)."
        case let .httpRequestFailed(response, body):
            return "Bad response from GitHub. Response: \(response), body: \(body)."
        case .invalidPublicKey:
            return "Invalid JWT signer public key."
        }
    }
}
