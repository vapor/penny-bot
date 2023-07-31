import GitHubAPI

extension Repository {
    var primaryBranch: String {
        self.master_branch ?? "main"
    }
}
