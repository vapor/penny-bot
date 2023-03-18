
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
    
    /// `[Expression: Set<UserID>]`
    public var items: [Expression: Set<String>] = [:]
    
    public init(items: [Expression: Set<String>] = [:]) {
        self.items = items
    }
}
