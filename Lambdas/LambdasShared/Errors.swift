enum Errors: Error, CustomStringConvertible {
    case envVarNotFound(name: String)
    case secretNotFound(arn: String)

    var description: String {
        switch self {
        case let .envVarNotFound(name):
            return "envVarNotFound(name: \(name))"
        case let .secretNotFound(arn):
            return "secretNotFound(arn: \(arn))"
        }
    }
}
