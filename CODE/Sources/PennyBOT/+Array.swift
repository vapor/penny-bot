
extension Array {
    func divided(
        _ isInLhs: (Element) async throws -> Bool
    ) async rethrows -> (lhs: [Element], rhs: [Element]) {
        var lhs = [Element]()
        var rhs = [Element]()
        lhs.reserveCapacity(self.count)
        rhs.reserveCapacity(self.count)

        for element in self {
            if try await isInLhs(element) {
                lhs.append(element)
            } else {
                rhs.append(element)
            }
        }
        return (lhs, rhs)
    }

    func divided(
        _ isInLhs: (Element) throws -> Bool
    ) rethrows -> (lhs: Array<Element>, rhs: Array<Element>) {
        var lhs = ContiguousArray<Element>()
        var rhs = ContiguousArray<Element>()

        var iterator = self.makeIterator()

        while let element = iterator.next() {
            if try isInLhs(element) {
                lhs.append(element)
            } else {
                rhs.append(element)
            }
        }

        return (Array(lhs), Array(rhs))
    }
}
