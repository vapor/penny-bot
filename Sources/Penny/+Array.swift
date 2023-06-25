
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
    ) rethrows -> (lhs: ArraySlice<Element>, rhs: ArraySlice<Element>) {
        var copy = self
        let firstOfRhs = try copy.partition(by: isInLhs)
        return (copy[firstOfRhs ..< copy.endIndex], copy[copy.startIndex ..< firstOfRhs])
    }
}
