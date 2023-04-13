import PennyModels

extension Collection<S3AutoPingItems.Expression> {
    /// Make sure the list in not empty before using this function.
    func makeExpressionListForDiscord() -> String {
        var matches = ContiguousArray<Element>()
        var contains = ContiguousArray<Element>()

        var iterator = self.makeIterator()

        while let element = iterator.next() {
            if element.kind == .exactMatch {
                matches.append(element)
            } else {
                contains.append(element)
            }
        }

        return [
            makeList(with: matches, kind: .exactMatch),
            makeList(with: contains, kind: .containment)
        ].joined(separator: "\n")
    }

    private func makeList(with elements: ContiguousArray<Element>, kind: Element.Kind) -> String {
        if elements.isEmpty {
            return ""
        } else {
            let list = elements
                .sorted(by: { $0.innerValue > $1.innerValue })
                .map(\.innerValue)
                .makeEnumeratedListForDiscord(leadingSpacesLength: 2)
            return """
            - \(kind.UIDescription):
            \(list)
            """
        }
    }
}

extension [S3AutoPingItems.Expression] {
    func divided(
        _ isInLhs: (Element) async throws -> Bool
    ) async rethrows -> (lhs: Array<Element>, rhs: Array<Element>) {
        var lhs = ContiguousArray<Element>()
        var rhs = ContiguousArray<Element>()
        
        var iterator = self.makeIterator()
        
        while let element = iterator.next() {
            if try await isInLhs(element) {
                lhs.append(element)
            } else {
                rhs.append(element)
            }
        }
        
        return (Array(lhs), Array(rhs))
    }
}
