
/// A box to treat `Any` as a Sendable type.
package class AnyBox: @unchecked Sendable {
    package let value: Any
    
    package init(_ value: Any) {
        self.value = value
    }
}
