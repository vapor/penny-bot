import Markdown

extension Document {
    func filterOutChildren(ofType: (some BlockMarkup).Type) -> Document {
        let children = self.blockChildren.filter {
            type(of: $0) != ofType
        }
        return Document(children)
    }
}
