import PennyModels

extension Sequence<S3AutoPingItems.Expression> {
    func makeExpressionListForDiscord() -> String {
        self.sorted(by: { $0.innerValue > $1.innerValue })
            .sorted(by: { $0.kindPriority > $1.kindPriority })
            .map(\.UIDescription)
            .makeEnumeratedListForDiscord()
    }
}

extension [S3AutoPingItems.Expression] {
    func divide(
        _ isInLhs: (Element) async throws -> Bool
    ) async rethrows -> (lhs: Self, rhs: Self) {
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
