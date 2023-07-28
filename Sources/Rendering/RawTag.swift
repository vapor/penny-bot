
struct RawTag: UnsafeUnescapedLeafTag {
    func render(_ context: LeafContext) throws -> LeafData {
        guard context.parameters.count > 0 else {
            throw "Parameter count more than 1: \(context.parameters.count)."
        }
        return .init(context.parameters[0].short)
    }
}
