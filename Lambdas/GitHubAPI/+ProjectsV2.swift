import OpenAPIRuntime

extension Components.Schemas.ProjectsV2ItemWithContent {
    /// The `node_id` of the item's content (the issue or pull request), if present.
    package var contentNodeID: String? {
        guard let content = self.content,
            let raw = content.additionalProperties.value["node_id"],
            let value = raw
        else {
            return nil
        }
        return value as? String
    }
}
