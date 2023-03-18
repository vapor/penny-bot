
/// The type containing all the auto-pings info of users.
/// Changes must be Codable-compatible or it'll corrupt the S3 file.
public struct S3AutoPingItems: Sendable, Codable {
    
    public enum Expression: Sendable, Codable, RawRepresentable, Hashable {
        case text(String)
        
        public var rawValue: String {
            switch self {
            case let .text(text):
                return "T-\(text)"
            }
        }
        
        public var innerValue: String {
            switch self {
            case let .text(text):
                return text
            }
        }
        
        public init? (rawValue: String) {
            if rawValue.hasPrefix("T-") {
                self = .text(String(rawValue.dropFirst(2)))
            } else {
                return nil
            }
        }
    }
    
    /// `[Expression: Set<PlainUserID>]`
    /// `PlainUserID` means something like `123456789938129`, and NOT `<@123456789938129>`.
    public var items: [Expression: Set<String>] = [:]
    
    /// `[Expression: Set<PlainUserID>]`
    /// `PlainUserID` means something like `123456789938129`, and NOT `<@123456789938129>`.
    public init(items: [Expression: Set<String>] = [:]) {
        self.items = items
    }
}
