
public struct S3AutoPingItems: Sendable, Codable {
    
    public enum Expression: Sendable, Codable, RawRepresentable, Hashable {
        /// Exact match (with some insensitivity, such as case-insensitivity)
        case match(String)
        /// Containment (with some insensitivity, such as case-insensitivity)
        case contain(String)
        
        public var rawValue: String {
            switch self {
            case let .match(match):
                return "T-\(match)"
            case let .contain(contain):
                return "C-\(contain)"
            }
        }
        
        /// Priority of the kind of expression.
        public var kindPriority: Int {
            switch self {
            case .match: return 2
            case .contain: return 1
            }
        }
        
        /// The description to be shown to users.
        public var UIDescription: String {
            switch self {
            case let .match(match):
                return #"match("\#(match)")"#
            case let .contain(contain):
                return #"contain("\#(contain)")"#
            }
        }
        
        public var innerValue: String {
            switch self {
            case let .match(match):
                return match
            case let .contain(contain):
                return contain
            }
        }
        
        public init? (rawValue: String) {
            if rawValue.hasPrefix("T-") {
                self = .match(String(rawValue.dropFirst(2)))
            } else if rawValue.hasPrefix("C-") {
                self = .contain(String(rawValue.dropFirst(2)))
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
