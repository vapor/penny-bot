extension Repository {
    package var primaryBranch: String {
        self.masterBranch ?? "main"
    }
}
