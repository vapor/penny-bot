enum Errors: Error, CustomStringConvertible {
    case runWorkflowError(message: String)
    case addMemberRoleError(message: String)
    case sendWelcomeMessageError(message: String)
    case envVarNotFound(key: String)

    var description: String {
        switch self {
        case let .runWorkflowError(message):
            return "runWorkflowError(\(message))"
        case let .addMemberRoleError(message):
            return "addMemberRoleError(\(message))"
        case let .sendWelcomeMessageError(message):
            return "sendWelcomeMessageError(\(message))"
        case let .envVarNotFound(key):
            return "envVarNotFound(key: \(key))"
        }
    }
}
