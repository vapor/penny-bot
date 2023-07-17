import Markdown

extension String {
    func formatForDiscord(maxLength: Int, trailingParagraphMinLength: Int) -> String {
        let document1 = Document(parsing: self)
        var htmlRemover = HTMLBlocksRemover()
        let markup1 = htmlRemover.visit(document1)

        let prefixed = (markup1?.format(options: .forDiscord) ?? "").unicodesPrefix(maxLength)
        let document2 = Document(parsing: prefixed)
        var paragraphCounter = ParagraphCounter()
        paragraphCounter.visit(document2)
        let paragraphCount = paragraphCounter.count
        if [0, 1].contains(paragraphCount) { return prefixed }
        var paragraphRemover = ParagraphRemover(
            atCount: paragraphCount,
            ifShorterThan: trailingParagraphMinLength
        )
        let markup2 = paragraphRemover.visit(document2)

        return markup2?.format(options: .forDiscord) ?? ""
    }
}

private extension MarkupFormatter.Options {
    static let forDiscord = MarkupFormatter.Options()
}

private struct HTMLBlocksRemover: MarkupRewriter {
    func visitHTMLBlock(_ html: HTMLBlock) -> (any Markup)? {
        return nil
    }
}

private struct ParagraphCounter: MarkupWalker {
    var count = 0

    mutating func visitParagraph(_ paragraph: Paragraph) {
        count += 1
    }
}

private struct ParagraphRemover: MarkupRewriter {
    let atCount: Int
    let ifShorterThan: Int
    var count = 0

    init(atCount: Int, ifShorterThan: Int) {
        self.atCount = atCount
        self.ifShorterThan = ifShorterThan
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> (any Markup)? {
        if count + 1 == atCount {
            if paragraph.format().unicodeScalars.count < ifShorterThan {
                return nil
            } else {
                return paragraph
            }
        } else {
            count += 1
            return paragraph
        }
    }
}
