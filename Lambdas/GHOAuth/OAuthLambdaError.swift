import AWSLambdaEvents

enum OAuthLambdaError: Error, CustomStringConvertible {
    case envVarNotFound(name: String)
    case unexpectedResponse(statusCode: Int)
    case secretNotFound(arn: String)

    var description: String {
        switch self {
        case let .envVarNotFound(name):
            return "Environment variable not found: \(name)"
        case let .unexpectedResponse(statusCode):
            return "Got unexpected response with status code: \(statusCode)"
        case let .secretNotFound(arn):
            return "Could not find secret with ARN: \(arn)"
        }
    }
}
