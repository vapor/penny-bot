
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

        public enum Repository: String, Sendable, Codable {
            case swift = "swift"
            case swiftCorelibsFoundation = "swift-corelibs-foundation"
            case swiftPackageManager = "swift-package-manager"
            case swiftXcodePlaygroundSupport = "swift-xcode-playground-support"
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
