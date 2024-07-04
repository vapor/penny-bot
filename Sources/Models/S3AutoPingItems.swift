
package struct S3AutoPingItems: Sendable, Codable {
    
    package enum Expression: Sendable, Codable, RawRepresentable, Hashable {

        package enum Kind: String, CaseIterable {
            case containment
            case exactMatch

            package static let `default`: Kind = .containment

            package var UIDescription: String {
                switch self {
                case .containment:
                    return "Containment"
                case .exactMatch:
                    return "Exact Match"
                }
            }

            package var priority: Int {
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
        
        package var kind: Kind {
            switch self {
            case .contains: return .containment
            case .matches: return .exactMatch
            }
        }
        
        package var innerValue: String {
            switch self {
            case let .contains(contain):
                return contain
            case let .matches(match):
                return match
            }
        }

        /// Important for the Codable conformance.
        /// Changing the implementation might result in breaking the repository.
        package var rawValue: String {
            switch self {
            case let .contains(contain):
                return "C-\(contain)"
            case let .matches(match):
                return "T-\(match)"
            }
        }

        /// Important for the Codable conformance.
        /// Changing the implementation might result in breaking the repository.
        package init? (rawValue: String) {
            if rawValue.hasPrefix("C-") {
                self = .contains(String(rawValue.dropFirst(2)))
            } else if rawValue.hasPrefix("T-") {
                self = .matches(String(rawValue.dropFirst(2)))
            } else {
                return nil
            }
        }
    }

    package var items: [Expression: Set<UserSnowflake>]

    package init(items: [Expression: Set<UserSnowflake>] = [:]) {
        self.items = items
    }
}
