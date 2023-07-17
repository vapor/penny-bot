import AWSLambdaEvents

enum OAuthLambdaError: Error, CustomStringConvertible {
    case envVarNotFound(name: String)
    case secretNotFound(arn: String)
    case badResponse(status: Int)
    case invalidPublicKey
    case invalidState

    var description: String {
        switch self {
        case let .envVarNotFound(name):
            return "Environment variable not found: \(name)"
        case let .secretNotFound(arn):
            return "Could not find secret with ARN: \(arn)"
        case let .badResponse(status):
            return "Bad response from GitHub: \(status)"
        case .invalidPublicKey:
            return "Invalid JWT signer public key"
        case .invalidState:
            return "Invalid state parameter"
        }

    }
}
