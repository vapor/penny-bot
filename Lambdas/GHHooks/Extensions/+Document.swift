import Markdown

extension Document {
    func removeHTMLBlocks() -> (any Markup)? {
        var deleter = HTMLBlockDeleter()
        let markup = deleter.visit(self)
        return markup
    }
}

private struct HTMLBlockDeleter: MarkupRewriter {
    func visitHTMLBlock(_ html: HTMLBlock) -> (any Markup)? {
        return nil
    }
}
