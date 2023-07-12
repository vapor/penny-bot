import Markdown

extension Document {
    /// Removes children of the provided type.
    func filterOutChildren(ofType: (some BlockMarkup).Type) -> Document {
        let children = self.blockChildren.filter {
            type(of: $0) != ofType
        }
        return Document(children)
    }
}
