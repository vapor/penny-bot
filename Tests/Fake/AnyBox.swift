
/// A box to treat `Any` as a Sendable type.
public class AnyBox: @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
}
