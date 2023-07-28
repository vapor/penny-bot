import Markdown

extension String {
    /// Formats markdown in a way that looks nice on Discord, but still good on GitHub.
    ///
    /// If you want to know why something is being done, comment out those lines and run the tests.
    func formatMarkdown(maxLength: Int, trailingParagraphMinLength: Int) -> String {
        let document1 = Document(parsing: self)
        var htmlRemover = HTMLAndImageRemover()
        guard let markup1 = htmlRemover.visit(document1) else { return "" }
        var emptyLinksRemover = EmptyLinksRemover()
        guard let markup2 = emptyLinksRemover.visit(markup1) else { return "" }

        let prefixed = markup2.format(options: .default)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodesPrefix(maxLength)
        let document2 = Document(parsing: prefixed)
        var paragraphCounter = ParagraphCounter()
        paragraphCounter.visit(document2)
        let paragraphCount = paragraphCounter.count
        if [0, 1].contains(paragraphCount) { return prefixed }
        var paragraphRemover = ParagraphRemover(
            atCount: paragraphCount,
            ifShorterThan: trailingParagraphMinLength
        )
        guard let markup3 = paragraphRemover.visit(document2) else { return "" }

        var formattedLines = markup3.format(options: .default)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        while formattedLines.first?.isWorthlessLineForTrim ?? false {
            formattedLines.removeFirst()
        }

        while formattedLines.last?.isWorthlessLineForTrim ?? false {
            formattedLines.removeLast()
        }

        return formattedLines.joined(separator: "\n")
    }
}

private extension MarkupFormatter.Options {
    static let `default` = Self()
}

private struct HTMLAndImageRemover: MarkupRewriter {
    func visitHTMLBlock(_ html: HTMLBlock) -> (any Markup)? {
        return nil
    }

    func visitImage(_ image: Image) -> (any Markup)? {
        return nil
    }
}

private struct EmptyLinksRemover: MarkupRewriter {
    func visitLink(_ link: Link) -> (any Markup)? {
        link.isEmpty ? nil : link
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

private extension StringProtocol {
    /// The line is worthless and can be trimmed.
    var isWorthlessLineForTrim: Bool {
        self.allSatisfy({ $0.isWhitespace || $0.isPunctuation })
    }
}
