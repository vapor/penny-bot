import Models
import DiscordBM

extension Collection<S3AutoPingItems.Expression> {
    /// Make sure the list in not empty before using this function.
    func makeExpressionListForDiscord() -> String {
        var matches = [Element]()
        var contains = [Element]()

        var iterator = self.makeIterator()

        while let element = iterator.next() {
            if element.kind == .exactMatch {
                matches.append(element)
            } else {
                contains.append(element)
            }
        }

        return [
            makeList(with: contains, kind: .containment),
            makeList(with: matches, kind: .exactMatch),
        ].compactMap { $0 }.joined(separator: "\n")
    }

    private func makeList(with elements: [Element], kind: Element.Kind) -> String? {
        if elements.isEmpty {
            return nil
        } else {
            let list = elements
                .sorted(by: { $0.innerValue > $1.innerValue })
                .map(\.innerValue)
                .makeExpressionListItems()
            return """
            - **\(kind.UIDescription)**
            \(list)
            """
        }
    }
}

private extension [String] {
    func makeExpressionListItems() -> String {
        self.enumerated().map { idx, text -> String in
            let escaped = DiscordUtils.escapingSpecialCharacters(text)
            return "  - \(escaped)"
        }.joined(separator: "\n")
    }
}
