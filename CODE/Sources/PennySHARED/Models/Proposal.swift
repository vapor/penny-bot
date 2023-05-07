
public struct Proposal: Codable {

    public struct User: Codable {
        public let link: String
        public let name: String
    }

    public struct Status: Codable {

        public enum State: String, Codable {
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

    public struct TrackingBug: Codable {
        public let assignee: String
        public let id: String
        public let link: String
        public let radar: String
        public let resolution: String
        public let status: String
        public let title: String
        public let updated: String
    }

    public struct Warning: Codable {
        public let kind: String
        public let message: String
        public let stage: String
    }

    public struct Implementation: Codable {

        public enum Account: String, Codable {
            case apple = "apple"
        }

        public enum Repository: String, Codable {
            case swift = "swift"
            case swiftCorelibsFoundation = "swift-corelibs-foundation"
            case swiftPackageManager = "swift-package-manager"
            case swiftXcodePlaygroundSupport = "swift-xcode-playground-support"
        }

        public enum Kind: String, Codable {
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
