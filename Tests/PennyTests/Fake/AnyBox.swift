
/// A box to treat `Any` as a Sendable type.
class AnyBox: @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
}
