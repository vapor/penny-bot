
public struct S3AutoPingItems: Sendable, Codable {
    
    public enum Expression: Sendable, Codable, RawRepresentable, Hashable {
        /// Exact match (with some insensitivity, such as case-insensitivity)
        case matches(String)
        /// Containment (with some insensitivity, such as case-insensitivity)
        case contains(String)
        
        /// Priority of the kind of expression.
        public var kindPriority: Int {
            switch self {
            case .matches: return 2
            case .contains: return 1
            }
        }
        
        /// The description to be shown to users.
        public var UIDescription: String {
            switch self {
            case let .matches(match):
                return #"matches("\#(match)")"#
            case let .contains(contain):
                return #"contains("\#(contain)")"#
            }
        }
        
        public var innerValue: String {
            switch self {
            case let .matches(match):
                return match
            case let .contains(contain):
                return contain
            }
        }

        /// Important for the Codable conformance.
        /// Changing the implementation might result in breaking the repository.
        public var rawValue: String {
            switch self {
            case let .matches(match):
                return "T-\(match)"
            case let .contains(contain):
                return "C-\(contain)"
            }
        }

        /// Important for the Codable conformance.
        /// Changing the implementation might result in breaking the repository.
        public init? (rawValue: String) {
            if rawValue.hasPrefix("T-") {
                self = .matches(String(rawValue.dropFirst(2)))
            } else if rawValue.hasPrefix("C-") {
                self = .contains(String(rawValue.dropFirst(2)))
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
