
struct RawTag: UnsafeUnescapedLeafTag {
    func render(_ context: LeafContext) throws -> LeafData {
        guard context.parameters.count == 1 else {
            throw "Unexpected parameter count: \(context.parameters.count)."
        }
        return .init(context.parameters[0].short)
    }
}
