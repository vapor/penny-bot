import GitHubAPI

extension Set<String> {
    /// Only supports names, and not emails.
    /// Assumes the strings are already all lowercased.
    func usernamesContain(user: User) -> Bool {
        if let name = user.name {
            return !self.intersection([user.login.lowercased(), name.lowercased()]).isEmpty
        } else {
            return self.contains(user.login.lowercased())
        }
    }

    /// Only supports names, and not emails.
    /// Assumes the strings are already all lowercased.
    func usernamesContain(user: NullableUser) -> Bool {
        if let name = user.name {
            return !self.intersection([user.login.lowercased(), name.lowercased()]).isEmpty
        } else {
            return self.contains(user.login.lowercased())
        }
    }
}
