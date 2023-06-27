
public struct S3AutoPingItems: Sendable, Codable {
    
    public enum Expression: Sendable, Codable, RawRepresentable, Hashable {

        public enum Kind: String, CaseIterable {
            case containment
            case exactMatch

            public static let `default`: Kind = .containment

            public var UIDescription: String {
                switch self {
                case .containment:
                    return "Containment"
                case .exactMatch:
                    return "Exact Match"
                }
            }

            public var priority: Int {
                switch self {
                case .containment:
                    return 2
                case .exactMatch:
                    return 1
                }
            }
        }

        /// Containment (with some insensitivity, such as case-insensitivity)
        case contains(String)
        /// Exact match (with some insensitivity, such as case-insensitivity)
        case matches(String)
        
        public var kind: Kind {
            switch self {
            case .contains: return .containment
            case .matches: return .exactMatch
            }
        }
        
        public var innerValue: String {
            switch self {
            case let .contains(contain):
                return contain
            case let .matches(match):
                return match
            }
        }

        /// Important for the Codable conformance.
        /// Changing the implementation might result in breaking the repository.
        public var rawValue: String {
            switch self {
            case let .contains(contain):
                return "C-\(contain)"
            case let .matches(match):
                return "T-\(match)"
            }
        }

        /// Important for the Codable conformance.
        /// Changing the implementation might result in breaking the repository.
        public init? (rawValue: String) {
            if rawValue.hasPrefix("C-") {
                self = .contains(String(rawValue.dropFirst(2)))
            } else if rawValue.hasPrefix("T-") {
                self = .matches(String(rawValue.dropFirst(2)))
            } else {
                return nil
            }
        }
    }
    
    /// `[Expression: Set<UserID>]`
    public var items: [Expression: Set<String>]
    
    public init(items: [Expression: Set<String>] = [:]) {
        self.items = items
    }
}
