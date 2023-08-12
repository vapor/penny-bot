extension Repository {
    public var primaryBranch: String {
        self.master_branch ?? "main"
    }
}
