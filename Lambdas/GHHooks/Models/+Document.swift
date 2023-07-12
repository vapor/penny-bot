import Markdown

extension Document {
    func filterOutChildren(ofType type: (some BlockMarkup).Type) -> Document {
        Document(self.blockChildren.filter { type(of: $0) != type }
    }
}
