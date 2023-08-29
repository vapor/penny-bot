import Markdown

extension String {
    /// Formats markdown in a way that looks nice on Discord, but still good on GitHub.
    ///
    /// If you want to know why something is being done, comment out those lines and run the tests.
    func formatMarkdown(
        maxVisualLength: Int,
        hardLimit: Int,
        trailingTextMinLength: Int
    ) -> String {
        assert(maxVisualLength > 0, "Can't request a non-positive maximum.")
        assert(hardLimit > 0, "Can't use a non-positive maximum.")
        assert(hardLimit >= maxVisualLength, "maxVisualLength '\(maxVisualLength)' can't be more than hardLimit '\(hardLimit)'.")

        let document1 = Document(parsing: self)
        var htmlRemover = HTMLAndImageRemover()
        guard let markup1 = htmlRemover.visit(document1) else { return "" }
        var emptyLinksRemover = EmptyLinksRemover()
        guard var markup2 = emptyLinksRemover.visit(markup1) else { return "" }

        let prefixed = markup2
            .format(options: .default)
            .trimmingForMarkdown()
            .markdownUnicodesPrefix(maxVisualLength)
            .unicodesPrefix(hardLimit)
        let document2 = Document(parsing: prefixed)
        var paragraphCounter = ParagraphCounter()
        paragraphCounter.visit(document2)
        let paragraphCount = paragraphCounter.count
        if ![0, 1].contains(paragraphCount) {
            var paragraphRemover = ParagraphRemover(
                atCount: paragraphCount,
                ifShorterThan: trailingTextMinLength
            )
            if let markup = paragraphRemover.visit(document2) {
                markup2 = markup
            }
        }

        var prefixed2 = markup2
            .format(options: .default)
            .trimmingForMarkdown()
            .markdownUnicodesPrefix(maxVisualLength)
            .unicodesPrefix(hardLimit)
        var document3 = Document(parsing: prefixed2)
        if let last = Array(document3.blockChildren).last,
           last is Heading {
            document3 = Document(document3.blockChildren.dropLast())
            prefixed2 = document3
                .format(options: .default)
                .trimmingForMarkdown()
                .markdownUnicodesPrefix(maxVisualLength)
                .unicodesPrefix(hardLimit)
        }

        return prefixed2
    }

    private func trimmingForMarkdown() -> String {
        self.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).trimmingWorthlessLines()
    }

    private func trimmingWorthlessLines() -> String {
        var lines = self.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        )

        while lines.first?.isWorthlessLineForTrim ?? false {
            lines.removeFirst()
        }

        while lines.last?.isWorthlessLineForTrim ?? false {
            lines.removeLast()
        }

        return lines.joined(separator: "\n")
    }

    /// Doesn't count markdown attributes towards the limit.
    @_disfavoredOverload
    func markdownUnicodesPrefix(_ maxLength: Int) -> (remaining: Int, result: String) {
        let document = Document(parsing: self)
        var rewriter = TextElementUnicodePrefixRewriter(maxLength: maxLength)
        let markup = rewriter.visitDocument(document)
        let result = markup?.format(options: .default) ?? ""
        return (rewriter.remainingLength, result)
    }

    /// Doesn't count markdown attributes towards the limit.
    func markdownUnicodesPrefix(_ maxLength: Int) -> String {
        markdownUnicodesPrefix(maxLength).result
    }

    func contentsOfHeading(named: String) -> String? {
        let document = Document(parsing: self)
        var headingFinder = HeadingFinder(name: named)
        headingFinder.visitDocument(document)
        if headingFinder.accumulated.isEmpty { return nil }
        let newDocument = Document(headingFinder.accumulated)
        return newDocument.format(options: .default)
    }

    func quotedMarkdown() -> String {
        self.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).map {
            "> \($0)"
        }.joined(
            separator: "\n"
        )
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
        defer { count += 1 }

        if count + 1 == atCount {
            var lengthCounter = MarkupLengthCounter()
            lengthCounter.visit(paragraph)
            if lengthCounter.length < ifShorterThan {
                return nil
            } else {
                return paragraph
            }
        } else {
            return paragraph
        }
    }
}

/// Should be kept in sync with `TextElementUnicodePrefixRewriter` down there.
private struct MarkupLengthCounter: MarkupWalker {
    var length = 0

    mutating func defaultVisit(_ markup: any Markup) {
        visitChildren(markup)
    }

    mutating func visitChildren(_ markup: any Markup) {
        for child in markup.children {
            var walker = MarkupLengthCounter()
            walker.visit(child)
            self.length += walker.length
        }
    }

    mutating func visitText(_ text: Text) {
        length += text.string.unicodeScalars.count
        visitChildren(text)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        length += inlineCode.code.unicodeScalars.count
        visitChildren(inlineCode)

    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        length += codeBlock.code.unicodeScalars.count
        visitChildren(codeBlock)
    }
}

/// Should be kept in sync with `MarkupLengthCounter` up there.
private struct TextElementUnicodePrefixRewriter: MarkupRewriter {
    var remainingLength: Int

    init(maxLength: Int) {
        self.remainingLength = maxLength
    }

    mutating func defaultVisit(_ markup: any Markup) -> (any Markup)? {
        visitChildren(markup)
    }

    mutating func visitChildren(_ markup: any Markup) -> any Markup {
        let newChildren = markup.children.compactMap { child -> (any Markup)? in
            if remainingLength == 0 { return nil }

            var rewriter = TextElementUnicodePrefixRewriter(maxLength: remainingLength)
            let result = rewriter.visit(child)
            self.remainingLength = rewriter.remainingLength
            return result
        }
        return markup.withUncheckedChildren(newChildren)
    }

    mutating func visitText(_ text: Text) -> (any Markup)? {
        if remainingLength == 0 { return nil }

        var text = text
        (remainingLength, text.string) = text.string.unicodesPrefix(remainingLength)

        return visitChildren(text)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> (any Markup)? {
        if remainingLength == 0 { return nil }

        var inlineCode = inlineCode
        (remainingLength, inlineCode.code) = inlineCode.code.unicodesPrefix(remainingLength)

        return visitChildren(inlineCode)

    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> (any Markup)? {
        if remainingLength == 0 { return nil }

        var codeBlock = codeBlock
        (remainingLength, codeBlock.code) = codeBlock.code.unicodesPrefix(remainingLength)

        return visitChildren(codeBlock)
    }
}

private extension StringProtocol {
    /// The line is worthless and can be trimmed.
    var isWorthlessLineForTrim: Bool {
        self.allSatisfy({ $0.isWhitespace || $0.isPunctuation })
    }
}

private struct HeadingFinder: MarkupWalker {
    let name: String
    var accumulated: [any BlockMarkup] = []
    var started = false
    var stopped = false

    init(name: String) {
        self.name = Self.fold(name)
    }

    private static func fold(_ string: String) -> String {
        string.filter({ !($0.isPunctuation || $0.isWhitespace) }).lowercased()
    }

    mutating func visit(_ markup: any Markup) {
        if stopped { return }
        if started {
            if type(of: markup) == Heading.self {
                self.stopped = true
            } else if let blockMarkup = markup as? (any BlockMarkup) {
                self.accumulated.append(blockMarkup)
            }
        } else {
            if let heading = markup as? Heading {
                if let firstChild = heading.children.first(where: { _ in true }),
                   let text = firstChild as? Text,
                   Self.fold(text.string) == name {
                    self.started = true
                }
            }
        }
    }
    }
