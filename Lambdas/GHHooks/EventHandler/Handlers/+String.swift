import GitHubAPI

extension String? {
    /// Usage example: `context.event.ref.extractHeadBranchFromRef()`
    func extractHeadBranchFromRef() -> Substring? {
        guard let ref = self, ref.hasPrefix("refs/heads/") else {
            return nil
        }
        return ref.dropFirst(11)
    }
}
