extension Repository {
    /// If it's a Vapor repository, use the raw repo name like `postgres-nio`.
    /// Otherwise use more of the repo name, like `community/stripe` for `vapor-community/stripe`.
    package var uiName: String {
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
    package var uiName: String {
        self.name ?? self.login
    }
}

extension NullableUser {
    package var uiName: String {
        self.name ?? self.login
    }
}
