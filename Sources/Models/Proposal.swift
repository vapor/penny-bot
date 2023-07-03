import Logging

public struct Proposal: Sendable, Codable {

    public struct User: Sendable, Codable {
        public let link: String
        public let name: String
    }

    public struct Status: Sendable, Codable {

        public enum State: String, Sendable, Codable {
            case accepted = ".accepted"
            case activeReview = ".activeReview"
            case implemented = ".implemented"
            case previewing = ".previewing"
            case rejected = ".rejected"
            case returnedForRevision = ".returnedForRevision"
            case withdrawn = ".withdrawn"
        }

        public let state: State
        public let version: String?
        public let end: String?
        public let start: String?
    }

    public struct TrackingBug: Sendable, Codable {
        public let assignee: String
        public let id: String
        public let link: String
        public let radar: String
        public let resolution: String
        public let status: String
        public let title: String
        public let updated: String
    }

    public struct Warning: Sendable, Codable {
        public let kind: String
        public let message: String
        public let stage: String
    }

    public struct Implementation: Sendable, Codable {

        public enum Account: String, Sendable, Codable {
            case apple = "apple"
        }

        public enum Repository: RawRepresentable, Sendable, Codable {
            case swift
            case swiftSyntax
            case swiftCorelibsFoundation
            case swiftPackageManager
            case swiftXcodePlaygroundSupport
            case unknown(String)

            public var rawValue: String {
                switch self {
                case .swift: return "swift"
                case .swiftSyntax: return "swift-syntax"
                case .swiftCorelibsFoundation: return "swift-corelibs-foundation"
                case .swiftPackageManager: return "swift-package-manager"
                case .swiftXcodePlaygroundSupport: return "swift-xcode-playground-support"
                case let .unknown(unknown): return unknown
                }
            }

            public init? (rawValue: String) {
                switch rawValue {
                case "swift": self = .swift
                case "swift-syntax": self = .swiftSyntax
                case "swift-corelibs-foundation": self = .swiftCorelibsFoundation
                case "swift-package-manager": self = .swiftPackageManager
                case "swift-xcode-playground-support": self = .swiftXcodePlaygroundSupport
                default:
                    Logger(label: "Proposal.Implementation.Repository").warning(
                        "New unknown 'Repository' case",
                        metadata: ["rawValue": .string(rawValue)]
                    )
                    self = .unknown(rawValue)
                }
            }
        }

        public enum Kind: String, Sendable, Codable {
            case commit = "commit"
            case pull = "pull"
        }

        public let account: Account
        public let id: String
        public let repository: Repository
        public let type: Kind
    }

    public let authors: [User]
    public let id: String
    public let link: String
    public let reviewManager: User
    public let sha: String
    public let status: Status
    public let summary: String
    public let title: String
    public let trackingBugs: [TrackingBug]?
    public let warnings: [Warning]?
    public let implementation: [Implementation]?
}
