
extension Repository {
    /// If it's a Vapor repository, use the raw repo name like `postgres-nio`.
    /// Otherwise use more of the repo name, like `community/stripe` for `vapor-community/stripe`.
    public var uiName: String {
        switch self.owner.login {
        case "vapor":
            return self.name
        case "vapor-community":
            return "community/\(self.name)"
        default:
            return self.full_name
        }
    }
}

extension User {
    public var uiName: String {
        self.name ?? self.login
    }
}

extension NullableUser {
    public var uiName: String {
        self.name ?? self.login
    }
}
