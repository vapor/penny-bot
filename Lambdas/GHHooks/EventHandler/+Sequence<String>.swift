import GitHubAPI

extension Set<String> {
    /// Only supports names, and not emails.
    func usernamesContain(user: User) -> Bool {
        if let name = user.name {
            return !self.intersection([user.login, name]).isEmpty
        } else {
            return self.contains(user.login)
        }
    }

    /// Only supports names, and not emails.
    func usernamesContain(user: NullableUser) -> Bool {
        if let name = user.name {
            return !self.intersection([user.login, name]).isEmpty
        } else {
            return self.contains(user.login)
        }
    }
}
