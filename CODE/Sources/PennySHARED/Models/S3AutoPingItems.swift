
public struct S3AutoPingItems: Codable {
    
    public enum Expression: Codable, RawRepresentable, Hashable {
        case text(String)
        
        public var rawValue: String {
            switch self {
            case let .text(text):
                return "TEXT-\(text)"
            }
        }
        
        public var innerValue: String {
            switch self {
            case let .text(text):
                return text
            }
        }
        
        public init? (rawValue: String) {
            if rawValue.hasPrefix("TEXT-") {
                self = .text(String(rawValue.dropFirst(5)))
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
