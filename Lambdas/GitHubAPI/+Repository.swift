
extension Repository {
    package var primaryBranch: String {
        self.master_branch ?? "main"
    }
}
