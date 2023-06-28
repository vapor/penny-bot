import AWSLambdaEvents

enum Errors: Error, CustomStringConvertible {
    case envVarNotFound(name: String)
    case secretNotFound(arn: String)
    case signatureHeaderNotFound(headers: AWSLambdaEvents.HTTPHeaders)
    case signaturesDoNotMatch(found: String, expected: String)

    var description: String {
        switch self {
        case let .envVarNotFound(name):
            return "envVarNotFound(name: \(name))"
        case let .secretNotFound(arn):
            return "secretNotFound(arn: \(arn))"
        case let .signatureHeaderNotFound(headers):
            return "signatureHeaderNotFound(headers: \(headers))"
        case let .signaturesDoNotMatch(found, expected):
            return "signaturesDoNotMatch(found: \(found), expected: \(expected)"
        }
    }
}
