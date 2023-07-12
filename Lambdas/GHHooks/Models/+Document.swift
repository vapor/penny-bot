import Markdown

extension Document {
    func filterOutChildren<T>(ofType: T.Type) -> Document where T: BlockMarkup {
        let children = self.blockChildren.filter { markup in
            type(of: markup) != ofType.self
        }
        return Document(children)
    }
}
