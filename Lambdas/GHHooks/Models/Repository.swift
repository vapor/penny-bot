import Foundation

/// Full Repository
// MARK: - Repository
struct Repository: Codable {
    let allowAutoMerge, allowForking, allowMergeCommit, allowRebaseMerge: Bool?
    let allowSquashMerge, allowUpdateBranch: Bool?
    /// Whether anonymous git access is allowed.
    let anonymousAccessEnabled: Bool?
    let archiveURL: String
    let archived: Bool
    let assigneesURL, blobsURL, branchesURL, cloneURL: String
    /// Code of Conduct Simple
    let codeOfConduct: CodeOfConductSimple?
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String
    let contentsURL, contributorsURL: String
    let createdAt: Date
    let defaultBranch: String
    let deleteBranchOnMerge: Bool?
    let deploymentsURL: String
    let description: String?
    /// Returns whether or not this repository disabled.
    let disabled: Bool
    let downloadsURL, eventsURL: String
    let fork: Bool
    let forks, forksCount: Int
    let forksURL, fullName, gitCommitsURL, gitRefsURL: String
    let gitTagsURL, gitURL: String
    let hasDiscussions, hasDownloads, hasIssues, hasPages: Bool
    let hasProjects, hasWiki: Bool
    let homepage: String?
    let hooksURL, htmlURL: String
    let id: Int
    let isTemplate: Bool?
    let issueCommentURL, issueEventsURL, issuesURL, keysURL: String
    let labelsURL: String
    let language: String?
    let languagesURL: String
    let license: PurpleLicenseSimple?
    let masterBranch: String?
    /// The default value for a merge commit message.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `PR_BODY` - default to the pull request's body.
    /// - `BLANK` - default to a blank commit message.
    let mergeCommitMessage: MergeCommitMessage?
    /// The default value for a merge commit title.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
    /// request #123 from branch-name).
    let mergeCommitTitle: MergeCommitTitle?
    let mergesURL, milestonesURL: String
    let mirrorURL: String?
    let name: String
    let networkCount: Int
    let nodeID, notificationsURL: String
    let openIssues, openIssuesCount: Int
    let organization: PurpleSimpleUser?
    /// A GitHub user.
    let owner: TentacledSimpleUser
    /// A repository on GitHub.
    let parent: ParentClass?
    let permissions: FluffyPermissions?
    let repositoryPrivate: Bool
    let pullsURL: String
    let pushedAt: Date
    let releasesURL: String
    let securityAndAnalysis: SecurityAndAnalysis?
    /// The size of the repository. Size is calculated hourly. When a repository is initially
    /// created, the size is 0.
    let size: Int
    /// A repository on GitHub.
    let source: SourceClass?
    /// The default value for a squash merge commit message:
    ///
    /// - `PR_BODY` - default to the pull request's body.
    /// - `COMMIT_MESSAGES` - default to the branch's commit messages.
    /// - `BLANK` - default to a blank commit message.
    let squashMergeCommitMessage: SquashMergeCommitMessage?
    /// The default value for a squash merge commit title:
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
    /// request's title (when more than one commit).
    let squashMergeCommitTitle: SquashMergeCommitTitle?
    let sshURL: String
    let stargazersCount: Int
    let stargazersURL, statusesURL: String
    let subscribersCount: Int
    let subscribersURL, subscriptionURL, svnURL, tagsURL: String
    let teamsURL: String
    let tempCloneToken: String?
    let templateRepository: RepositoryClass?
    let topics: [String]?
    let treesURL: String
    let updatedAt: Date
    let url: String
    let useSquashPRTitleAsDefault: Bool?
    /// The repository visibility: public, private, or internal.
    let visibility: String?
    let watchers, watchersCount: Int
    let webCommitSignoffRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case allowAutoMerge
        case allowForking
        case allowMergeCommit
        case allowRebaseMerge
        case allowSquashMerge
        case allowUpdateBranch
        case anonymousAccessEnabled
        case archiveURL
        case archived
        case assigneesURL
        case blobsURL
        case branchesURL
        case cloneURL
        case codeOfConduct
        case collaboratorsURL
        case commentsURL
        case commitsURL
        case compareURL
        case contentsURL
        case contributorsURL
        case createdAt
        case defaultBranch
        case deleteBranchOnMerge
        case deploymentsURL
        case description, disabled
        case downloadsURL
        case eventsURL
        case fork, forks
        case forksCount
        case forksURL
        case fullName
        case gitCommitsURL
        case gitRefsURL
        case gitTagsURL
        case gitURL
        case hasDiscussions
        case hasDownloads
        case hasIssues
        case hasPages
        case hasProjects
        case hasWiki
        case homepage
        case hooksURL
        case htmlURL
        case id
        case isTemplate
        case issueCommentURL
        case issueEventsURL
        case issuesURL
        case keysURL
        case labelsURL
        case language
        case languagesURL
        case license
        case masterBranch
        case mergeCommitMessage
        case mergeCommitTitle
        case mergesURL
        case milestonesURL
        case mirrorURL
        case name
        case networkCount
        case nodeID
        case notificationsURL
        case openIssues
        case openIssuesCount
        case organization, owner, parent, permissions
        case repositoryPrivate
        case pullsURL
        case pushedAt
        case releasesURL
        case securityAndAnalysis
        case size, source
        case squashMergeCommitMessage
        case squashMergeCommitTitle
        case sshURL
        case stargazersCount
        case stargazersURL
        case statusesURL
        case subscribersCount
        case subscribersURL
        case subscriptionURL
        case svnURL
        case tagsURL
        case teamsURL
        case tempCloneToken
        case templateRepository
        case topics
        case treesURL
        case updatedAt
        case url
        case useSquashPRTitleAsDefault
        case visibility, watchers
        case watchersCount
        case webCommitSignoffRequired
    }
}

/// Code of Conduct Simple
// MARK: - CodeOfConductSimple
struct CodeOfConductSimple: Codable {
    let htmlURL: String?
    let key, name, url: String

    enum CodingKeys: String, CodingKey {
        case htmlURL
        case key, name, url
    }
}

/// License Simple
// MARK: - PurpleLicenseSimple
struct PurpleLicenseSimple: Codable {
    let htmlURL: String?
    let key, name, nodeID: String
    let spdxID, url: String?

    enum CodingKeys: String, CodingKey {
        case htmlURL
        case key, name
        case nodeID
        case spdxID
        case url
    }
}

/// The default value for a merge commit message.
///
/// - `PR_TITLE` - default to the pull request's title.
/// - `PR_BODY` - default to the pull request's body.
/// - `BLANK` - default to a blank commit message.
enum MergeCommitMessage: String, Codable {
    case blank = "BLANK"
    case prBody = "PR_BODY"
    case prTitle = "PR_TITLE"
}

/// The default value for a merge commit title.
///
/// - `PR_TITLE` - default to the pull request's title.
/// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
/// request #123 from branch-name).
///
/// The default value for a merge commit title.
///
/// - `PR_TITLE` - default to the pull request's title.
/// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
/// request #123 from branch-name).
enum MergeCommitTitle: String, Codable {
    case mergeMessage = "MERGE_MESSAGE"
    case prTitle = "PR_TITLE"
}

/// A GitHub user.
// MARK: - PurpleSimpleUser
struct PurpleSimpleUser: Codable {
    let avatarURL: String
    let email: String?
    let eventsURL, followersURL, followingURL, gistsURL: String
    let gravatarID: String?
    let htmlURL: String
    let id: Int
    let login: String
    let name: String?
    let nodeID, organizationsURL, receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredAt: String?
    let starredURL, subscriptionsURL, type, url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case email
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login, name
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredAt
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

/// A GitHub user.
// MARK: - TentacledSimpleUser
struct TentacledSimpleUser: Codable {
    let avatarURL: String
    let email: String?
    let eventsURL, followersURL, followingURL, gistsURL: String
    let gravatarID: String?
    let htmlURL: String
    let id: Int
    let login: String
    let name: String?
    let nodeID, organizationsURL, receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredAt: String?
    let starredURL, subscriptionsURL, type, url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case email
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login, name
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredAt
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

/// A repository on GitHub.
// MARK: - ParentClass
struct ParentClass: Codable {
    /// Whether to allow Auto-merge to be used on pull requests.
    let allowAutoMerge: Bool?
    /// Whether to allow forking this repo
    let allowForking: Bool?
    /// Whether to allow merge commits for pull requests.
    let allowMergeCommit: Bool?
    /// Whether to allow rebase merges for pull requests.
    let allowRebaseMerge: Bool?
    /// Whether to allow squash merges for pull requests.
    let allowSquashMerge: Bool?
    /// Whether or not a pull request head branch that is behind its base branch can always be
    /// updated even if it is not required to be up to date before merging.
    let allowUpdateBranch: Bool?
    /// Whether anonymous git access is enabled for this repository
    let anonymousAccessEnabled: Bool?
    let archiveURL: String
    /// Whether the repository is archived.
    let archived: Bool
    let assigneesURL, blobsURL, branchesURL, cloneURL: String
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String
    let contentsURL, contributorsURL: String
    let createdAt: Date?
    /// The default branch of the repository.
    let defaultBranch: String
    /// Whether to delete head branches when pull requests are merged
    let deleteBranchOnMerge: Bool?
    let deploymentsURL: String
    let description: String?
    /// Returns whether or not this repository disabled.
    let disabled: Bool
    let downloadsURL, eventsURL: String
    let fork: Bool
    let forks, forksCount: Int
    let forksURL, fullName, gitCommitsURL, gitRefsURL: String
    let gitTagsURL, gitURL: String
    /// Whether discussions are enabled.
    let hasDiscussions: Bool?
    /// Whether downloads are enabled.
    let hasDownloads: Bool
    /// Whether issues are enabled.
    let hasIssues: Bool
    let hasPages: Bool
    /// Whether projects are enabled.
    let hasProjects: Bool
    /// Whether the wiki is enabled.
    let hasWiki: Bool
    let homepage: String?
    let hooksURL, htmlURL: String
    /// Unique identifier of the repository
    let id: Int
    /// Whether this repository acts as a template that can be used to generate new repositories.
    let isTemplate: Bool?
    let issueCommentURL, issueEventsURL, issuesURL, keysURL: String
    let labelsURL: String
    let language: String?
    let languagesURL: String
    let license: ParentLicenseSimple?
    let masterBranch: String?
    /// The default value for a merge commit message.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `PR_BODY` - default to the pull request's body.
    /// - `BLANK` - default to a blank commit message.
    let mergeCommitMessage: MergeCommitMessage?
    /// The default value for a merge commit title.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
    /// request #123 from branch-name).
    let mergeCommitTitle: MergeCommitTitle?
    let mergesURL, milestonesURL: String
    let mirrorURL: String?
    /// The name of the repository.
    let name: String
    let networkCount: Int?
    let nodeID, notificationsURL: String
    let openIssues, openIssuesCount: Int
    let organization: ParentSimpleUser?
    /// A GitHub user.
    let owner: ParentOwner
    let permissions: ParentPermissions?
    /// Whether the repository is private or public.
    let repositoryPrivate: Bool
    let pullsURL: String
    let pushedAt: Date?
    let releasesURL: String
    /// The size of the repository. Size is calculated hourly. When a repository is initially
    /// created, the size is 0.
    let size: Int
    /// The default value for a squash merge commit message:
    ///
    /// - `PR_BODY` - default to the pull request's body.
    /// - `COMMIT_MESSAGES` - default to the branch's commit messages.
    /// - `BLANK` - default to a blank commit message.
    let squashMergeCommitMessage: SquashMergeCommitMessage?
    /// The default value for a squash merge commit title:
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
    /// request's title (when more than one commit).
    let squashMergeCommitTitle: SquashMergeCommitTitle?
    let sshURL: String
    let stargazersCount: Int
    let stargazersURL: String
    let starredAt: String?
    let statusesURL: String
    let subscribersCount: Int?
    let subscribersURL, subscriptionURL, svnURL, tagsURL: String
    let teamsURL: String
    let tempCloneToken: String?
    let templateRepository: ParentTemplateRepository?
    let topics: [String]?
    let treesURL: String
    let updatedAt: Date?
    let url: String
    /// Whether a squash merge commit can use the pull request title as default. **This property
    /// has been deprecated. Please use `squash_merge_commit_title` instead.
    let useSquashPRTitleAsDefault: Bool?
    /// The repository visibility: public, private, or internal.
    let visibility: String?
    let watchers, watchersCount: Int
    /// Whether to require contributors to sign off on web-based commits
    let webCommitSignoffRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case allowAutoMerge
        case allowForking
        case allowMergeCommit
        case allowRebaseMerge
        case allowSquashMerge
        case allowUpdateBranch
        case anonymousAccessEnabled
        case archiveURL
        case archived
        case assigneesURL
        case blobsURL
        case branchesURL
        case cloneURL
        case collaboratorsURL
        case commentsURL
        case commitsURL
        case compareURL
        case contentsURL
        case contributorsURL
        case createdAt
        case defaultBranch
        case deleteBranchOnMerge
        case deploymentsURL
        case description, disabled
        case downloadsURL
        case eventsURL
        case fork, forks
        case forksCount
        case forksURL
        case fullName
        case gitCommitsURL
        case gitRefsURL
        case gitTagsURL
        case gitURL
        case hasDiscussions
        case hasDownloads
        case hasIssues
        case hasPages
        case hasProjects
        case hasWiki
        case homepage
        case hooksURL
        case htmlURL
        case id
        case isTemplate
        case issueCommentURL
        case issueEventsURL
        case issuesURL
        case keysURL
        case labelsURL
        case language
        case languagesURL
        case license
        case masterBranch
        case mergeCommitMessage
        case mergeCommitTitle
        case mergesURL
        case milestonesURL
        case mirrorURL
        case name
        case networkCount
        case nodeID
        case notificationsURL
        case openIssues
        case openIssuesCount
        case organization, owner, permissions
        case repositoryPrivate
        case pullsURL
        case pushedAt
        case releasesURL
        case size
        case squashMergeCommitMessage
        case squashMergeCommitTitle
        case sshURL
        case stargazersCount
        case stargazersURL
        case starredAt
        case statusesURL
        case subscribersCount
        case subscribersURL
        case subscriptionURL
        case svnURL
        case tagsURL
        case teamsURL
        case tempCloneToken
        case templateRepository
        case topics
        case treesURL
        case updatedAt
        case url
        case useSquashPRTitleAsDefault
        case visibility, watchers
        case watchersCount
        case webCommitSignoffRequired
    }
}

/// License Simple
// MARK: - ParentLicenseSimple
struct ParentLicenseSimple: Codable {
    let htmlURL: String?
    let key, name, nodeID: String
    let spdxID, url: String?

    enum CodingKeys: String, CodingKey {
        case htmlURL
        case key, name
        case nodeID
        case spdxID
        case url
    }
}

/// A GitHub user.
// MARK: - ParentSimpleUser
struct ParentSimpleUser: Codable {
    let avatarURL: String
    let email: String?
    let eventsURL, followersURL, followingURL, gistsURL: String
    let gravatarID: String?
    let htmlURL: String
    let id: Int
    let login: String
    let name: String?
    let nodeID, organizationsURL, receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredAt: String?
    let starredURL, subscriptionsURL, type, url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case email
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login, name
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredAt
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

/// A GitHub user.
// MARK: - ParentOwner
struct ParentOwner: Codable {
    let avatarURL: String
    let email: String?
    let eventsURL, followersURL, followingURL, gistsURL: String
    let gravatarID: String?
    let htmlURL: String
    let id: Int
    let login: String
    let name: String?
    let nodeID, organizationsURL, receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredAt: String?
    let starredURL, subscriptionsURL, type, url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case email
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login, name
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredAt
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

// MARK: - ParentPermissions
struct ParentPermissions: Codable {
    let admin: Bool
    let maintain: Bool?
    let pull, push: Bool
    let triage: Bool?
}

/// The default value for a squash merge commit message:
///
/// - `PR_BODY` - default to the pull request's body.
/// - `COMMIT_MESSAGES` - default to the branch's commit messages.
/// - `BLANK` - default to a blank commit message.
enum SquashMergeCommitMessage: String, Codable {
    case blank = "BLANK"
    case commitMessages = "COMMIT_MESSAGES"
    case prBody = "PR_BODY"
}

/// The default value for a squash merge commit title:
///
/// - `PR_TITLE` - default to the pull request's title.
/// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
/// request's title (when more than one commit).
enum SquashMergeCommitTitle: String, Codable {
    case commitOrPRTitle = "COMMIT_OR_PR_TITLE"
    case prTitle = "PR_TITLE"
}

// MARK: - ParentTemplateRepository
struct ParentTemplateRepository: Codable {
    let allowAutoMerge, allowMergeCommit, allowRebaseMerge, allowSquashMerge: Bool?
    let allowUpdateBranch: Bool?
    let archiveURL: String?
    let archived: Bool?
    let assigneesURL, blobsURL, branchesURL, cloneURL: String?
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String?
    let contentsURL, contributorsURL, createdAt, defaultBranch: String?
    let deleteBranchOnMerge: Bool?
    let deploymentsURL, description: String?
    let disabled: Bool?
    let downloadsURL, eventsURL: String?
    let fork: Bool?
    let forksCount: Int?
    let forksURL, fullName, gitCommitsURL, gitRefsURL: String?
    let gitTagsURL, gitURL: String?
    let hasDownloads, hasIssues, hasPages, hasProjects: Bool?
    let hasWiki: Bool?
    let homepage, hooksURL, htmlURL: String?
    let id: Int?
    let isTemplate: Bool?
    let issueCommentURL, issueEventsURL, issuesURL, keysURL: String?
    let labelsURL, language, languagesURL: String?
    /// The default value for a merge commit message.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `PR_BODY` - default to the pull request's body.
    /// - `BLANK` - default to a blank commit message.
    let mergeCommitMessage: MergeCommitMessage?
    /// The default value for a merge commit title.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
    /// request #123 from branch-name).
    let mergeCommitTitle: MergeCommitTitle?
    let mergesURL, milestonesURL, mirrorURL, name: String?
    let networkCount: Int?
    let nodeID, notificationsURL: String?
    let openIssuesCount: Int?
    let owner: PurpleOwner?
    let permissions: PurplePermissions?
    let templateRepositoryPrivate: Bool?
    let pullsURL, pushedAt, releasesURL: String?
    let size: Int?
    /// The default value for a squash merge commit message:
    ///
    /// - `PR_BODY` - default to the pull request's body.
    /// - `COMMIT_MESSAGES` - default to the branch's commit messages.
    /// - `BLANK` - default to a blank commit message.
    let squashMergeCommitMessage: SquashMergeCommitMessage?
    /// The default value for a squash merge commit title:
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
    /// request's title (when more than one commit).
    let squashMergeCommitTitle: SquashMergeCommitTitle?
    let sshURL: String?
    let stargazersCount: Int?
    let stargazersURL, statusesURL: String?
    let subscribersCount: Int?
    let subscribersURL, subscriptionURL, svnURL, tagsURL: String?
    let teamsURL, tempCloneToken: String?
    let topics: [String]?
    let treesURL, updatedAt, url: String?
    let useSquashPRTitleAsDefault: Bool?
    let visibility: String?
    let watchersCount: Int?

    enum CodingKeys: String, CodingKey {
        case allowAutoMerge
        case allowMergeCommit
        case allowRebaseMerge
        case allowSquashMerge
        case allowUpdateBranch
        case archiveURL
        case archived
        case assigneesURL
        case blobsURL
        case branchesURL
        case cloneURL
        case collaboratorsURL
        case commentsURL
        case commitsURL
        case compareURL
        case contentsURL
        case contributorsURL
        case createdAt
        case defaultBranch
        case deleteBranchOnMerge
        case deploymentsURL
        case description, disabled
        case downloadsURL
        case eventsURL
        case fork
        case forksCount
        case forksURL
        case fullName
        case gitCommitsURL
        case gitRefsURL
        case gitTagsURL
        case gitURL
        case hasDownloads
        case hasIssues
        case hasPages
        case hasProjects
        case hasWiki
        case homepage
        case hooksURL
        case htmlURL
        case id
        case isTemplate
        case issueCommentURL
        case issueEventsURL
        case issuesURL
        case keysURL
        case labelsURL
        case language
        case languagesURL
        case mergeCommitMessage
        case mergeCommitTitle
        case mergesURL
        case milestonesURL
        case mirrorURL
        case name
        case networkCount
        case nodeID
        case notificationsURL
        case openIssuesCount
        case owner, permissions
        case templateRepositoryPrivate
        case pullsURL
        case pushedAt
        case releasesURL
        case size
        case squashMergeCommitMessage
        case squashMergeCommitTitle
        case sshURL
        case stargazersCount
        case stargazersURL
        case statusesURL
        case subscribersCount
        case subscribersURL
        case subscriptionURL
        case svnURL
        case tagsURL
        case teamsURL
        case tempCloneToken
        case topics
        case treesURL
        case updatedAt
        case url
        case useSquashPRTitleAsDefault
        case visibility
        case watchersCount
    }
}

// MARK: - PurpleOwner
struct PurpleOwner: Codable {
    let avatarURL, eventsURL, followersURL, followingURL: String?
    let gistsURL, gravatarID, htmlURL: String?
    let id: Int?
    let login, nodeID, organizationsURL, receivedEventsURL: String?
    let reposURL: String?
    let siteAdmin: Bool?
    let starredURL, subscriptionsURL, type, url: String?

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

// MARK: - PurplePermissions
struct PurplePermissions: Codable {
    let admin, maintain, pull, push: Bool?
    let triage: Bool?
}

// MARK: - FluffyPermissions
struct FluffyPermissions: Codable {
    let admin: Bool
    let maintain: Bool?
    let pull, push: Bool
    let triage: Bool?
}

// MARK: - SecurityAndAnalysis
struct SecurityAndAnalysis: Codable {
    let advancedSecurity: AdvancedSecurity?
    let secretScanning: SecretScanning?
    let secretScanningPushProtection: SecretScanningPushProtection?

    enum CodingKeys: String, CodingKey {
        case advancedSecurity
        case secretScanning
        case secretScanningPushProtection
    }
}

// MARK: - AdvancedSecurity
struct AdvancedSecurity: Codable {
    let status: Status?
}

enum Status: String, Codable {
    case disabled = "disabled"
    case enabled = "enabled"
}

// MARK: - SecretScanning
struct SecretScanning: Codable {
    let status: Status?
}

// MARK: - SecretScanningPushProtection
struct SecretScanningPushProtection: Codable {
    let status: Status?
}

/// A repository on GitHub.
// MARK: - SourceClass
struct SourceClass: Codable {
    /// Whether to allow Auto-merge to be used on pull requests.
    let allowAutoMerge: Bool?
    /// Whether to allow forking this repo
    let allowForking: Bool?
    /// Whether to allow merge commits for pull requests.
    let allowMergeCommit: Bool?
    /// Whether to allow rebase merges for pull requests.
    let allowRebaseMerge: Bool?
    /// Whether to allow squash merges for pull requests.
    let allowSquashMerge: Bool?
    /// Whether or not a pull request head branch that is behind its base branch can always be
    /// updated even if it is not required to be up to date before merging.
    let allowUpdateBranch: Bool?
    /// Whether anonymous git access is enabled for this repository
    let anonymousAccessEnabled: Bool?
    let archiveURL: String
    /// Whether the repository is archived.
    let archived: Bool
    let assigneesURL, blobsURL, branchesURL, cloneURL: String
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String
    let contentsURL, contributorsURL: String
    let createdAt: Date?
    /// The default branch of the repository.
    let defaultBranch: String
    /// Whether to delete head branches when pull requests are merged
    let deleteBranchOnMerge: Bool?
    let deploymentsURL: String
    let description: String?
    /// Returns whether or not this repository disabled.
    let disabled: Bool
    let downloadsURL, eventsURL: String
    let fork: Bool
    let forks, forksCount: Int
    let forksURL, fullName, gitCommitsURL, gitRefsURL: String
    let gitTagsURL, gitURL: String
    /// Whether discussions are enabled.
    let hasDiscussions: Bool?
    /// Whether downloads are enabled.
    let hasDownloads: Bool
    /// Whether issues are enabled.
    let hasIssues: Bool
    let hasPages: Bool
    /// Whether projects are enabled.
    let hasProjects: Bool
    /// Whether the wiki is enabled.
    let hasWiki: Bool
    let homepage: String?
    let hooksURL, htmlURL: String
    /// Unique identifier of the repository
    let id: Int
    /// Whether this repository acts as a template that can be used to generate new repositories.
    let isTemplate: Bool?
    let issueCommentURL, issueEventsURL, issuesURL, keysURL: String
    let labelsURL: String
    let language: String?
    let languagesURL: String
    let license: SourceLicenseSimple?
    let masterBranch: String?
    /// The default value for a merge commit message.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `PR_BODY` - default to the pull request's body.
    /// - `BLANK` - default to a blank commit message.
    let mergeCommitMessage: MergeCommitMessage?
    /// The default value for a merge commit title.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
    /// request #123 from branch-name).
    let mergeCommitTitle: MergeCommitTitle?
    let mergesURL, milestonesURL: String
    let mirrorURL: String?
    /// The name of the repository.
    let name: String
    let networkCount: Int?
    let nodeID, notificationsURL: String
    let openIssues, openIssuesCount: Int
    let organization: SourceSimpleUser?
    /// A GitHub user.
    let owner: SourceOwner
    let permissions: SourcePermissions?
    /// Whether the repository is private or public.
    let repositoryPrivate: Bool
    let pullsURL: String
    let pushedAt: Date?
    let releasesURL: String
    /// The size of the repository. Size is calculated hourly. When a repository is initially
    /// created, the size is 0.
    let size: Int
    /// The default value for a squash merge commit message:
    ///
    /// - `PR_BODY` - default to the pull request's body.
    /// - `COMMIT_MESSAGES` - default to the branch's commit messages.
    /// - `BLANK` - default to a blank commit message.
    let squashMergeCommitMessage: SquashMergeCommitMessage?
    /// The default value for a squash merge commit title:
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
    /// request's title (when more than one commit).
    let squashMergeCommitTitle: SquashMergeCommitTitle?
    let sshURL: String
    let stargazersCount: Int
    let stargazersURL: String
    let starredAt: String?
    let statusesURL: String
    let subscribersCount: Int?
    let subscribersURL, subscriptionURL, svnURL, tagsURL: String
    let teamsURL: String
    let tempCloneToken: String?
    let templateRepository: SourceTemplateRepository?
    let topics: [String]?
    let treesURL: String
    let updatedAt: Date?
    let url: String
    /// Whether a squash merge commit can use the pull request title as default. **This property
    /// has been deprecated. Please use `squash_merge_commit_title` instead.
    let useSquashPRTitleAsDefault: Bool?
    /// The repository visibility: public, private, or internal.
    let visibility: String?
    let watchers, watchersCount: Int
    /// Whether to require contributors to sign off on web-based commits
    let webCommitSignoffRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case allowAutoMerge
        case allowForking
        case allowMergeCommit
        case allowRebaseMerge
        case allowSquashMerge
        case allowUpdateBranch
        case anonymousAccessEnabled
        case archiveURL
        case archived
        case assigneesURL
        case blobsURL
        case branchesURL
        case cloneURL
        case collaboratorsURL
        case commentsURL
        case commitsURL
        case compareURL
        case contentsURL
        case contributorsURL
        case createdAt
        case defaultBranch
        case deleteBranchOnMerge
        case deploymentsURL
        case description, disabled
        case downloadsURL
        case eventsURL
        case fork, forks
        case forksCount
        case forksURL
        case fullName
        case gitCommitsURL
        case gitRefsURL
        case gitTagsURL
        case gitURL
        case hasDiscussions
        case hasDownloads
        case hasIssues
        case hasPages
        case hasProjects
        case hasWiki
        case homepage
        case hooksURL
        case htmlURL
        case id
        case isTemplate
        case issueCommentURL
        case issueEventsURL
        case issuesURL
        case keysURL
        case labelsURL
        case language
        case languagesURL
        case license
        case masterBranch
        case mergeCommitMessage
        case mergeCommitTitle
        case mergesURL
        case milestonesURL
        case mirrorURL
        case name
        case networkCount
        case nodeID
        case notificationsURL
        case openIssues
        case openIssuesCount
        case organization, owner, permissions
        case repositoryPrivate
        case pullsURL
        case pushedAt
        case releasesURL
        case size
        case squashMergeCommitMessage
        case squashMergeCommitTitle
        case sshURL
        case stargazersCount
        case stargazersURL
        case starredAt
        case statusesURL
        case subscribersCount
        case subscribersURL
        case subscriptionURL
        case svnURL
        case tagsURL
        case teamsURL
        case tempCloneToken
        case templateRepository
        case topics
        case treesURL
        case updatedAt
        case url
        case useSquashPRTitleAsDefault
        case visibility, watchers
        case watchersCount
        case webCommitSignoffRequired
    }
}

/// License Simple
// MARK: - SourceLicenseSimple
struct SourceLicenseSimple: Codable {
    let htmlURL: String?
    let key, name, nodeID: String
    let spdxID, url: String?

    enum CodingKeys: String, CodingKey {
        case htmlURL
        case key, name
        case nodeID
        case spdxID
        case url
    }
}

/// A GitHub user.
// MARK: - SourceSimpleUser
struct SourceSimpleUser: Codable {
    let avatarURL: String
    let email: String?
    let eventsURL, followersURL, followingURL, gistsURL: String
    let gravatarID: String?
    let htmlURL: String
    let id: Int
    let login: String
    let name: String?
    let nodeID, organizationsURL, receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredAt: String?
    let starredURL, subscriptionsURL, type, url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case email
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login, name
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredAt
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

/// A GitHub user.
// MARK: - SourceOwner
struct SourceOwner: Codable {
    let avatarURL: String
    let email: String?
    let eventsURL, followersURL, followingURL, gistsURL: String
    let gravatarID: String?
    let htmlURL: String
    let id: Int
    let login: String
    let name: String?
    let nodeID, organizationsURL, receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredAt: String?
    let starredURL, subscriptionsURL, type, url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case email
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login, name
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredAt
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

// MARK: - SourcePermissions
struct SourcePermissions: Codable {
    let admin: Bool
    let maintain: Bool?
    let pull, push: Bool
    let triage: Bool?
}

// MARK: - SourceTemplateRepository
struct SourceTemplateRepository: Codable {
    let allowAutoMerge, allowMergeCommit, allowRebaseMerge, allowSquashMerge: Bool?
    let allowUpdateBranch: Bool?
    let archiveURL: String?
    let archived: Bool?
    let assigneesURL, blobsURL, branchesURL, cloneURL: String?
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String?
    let contentsURL, contributorsURL, createdAt, defaultBranch: String?
    let deleteBranchOnMerge: Bool?
    let deploymentsURL, description: String?
    let disabled: Bool?
    let downloadsURL, eventsURL: String?
    let fork: Bool?
    let forksCount: Int?
    let forksURL, fullName, gitCommitsURL, gitRefsURL: String?
    let gitTagsURL, gitURL: String?
    let hasDownloads, hasIssues, hasPages, hasProjects: Bool?
    let hasWiki: Bool?
    let homepage, hooksURL, htmlURL: String?
    let id: Int?
    let isTemplate: Bool?
    let issueCommentURL, issueEventsURL, issuesURL, keysURL: String?
    let labelsURL, language, languagesURL: String?
    /// The default value for a merge commit message.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `PR_BODY` - default to the pull request's body.
    /// - `BLANK` - default to a blank commit message.
    let mergeCommitMessage: MergeCommitMessage?
    /// The default value for a merge commit title.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
    /// request #123 from branch-name).
    let mergeCommitTitle: MergeCommitTitle?
    let mergesURL, milestonesURL, mirrorURL, name: String?
    let networkCount: Int?
    let nodeID, notificationsURL: String?
    let openIssuesCount: Int?
    let owner: FluffyOwner?
    let permissions: TentacledPermissions?
    let templateRepositoryPrivate: Bool?
    let pullsURL, pushedAt, releasesURL: String?
    let size: Int?
    /// The default value for a squash merge commit message:
    ///
    /// - `PR_BODY` - default to the pull request's body.
    /// - `COMMIT_MESSAGES` - default to the branch's commit messages.
    /// - `BLANK` - default to a blank commit message.
    let squashMergeCommitMessage: SquashMergeCommitMessage?
    /// The default value for a squash merge commit title:
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
    /// request's title (when more than one commit).
    let squashMergeCommitTitle: SquashMergeCommitTitle?
    let sshURL: String?
    let stargazersCount: Int?
    let stargazersURL, statusesURL: String?
    let subscribersCount: Int?
    let subscribersURL, subscriptionURL, svnURL, tagsURL: String?
    let teamsURL, tempCloneToken: String?
    let topics: [String]?
    let treesURL, updatedAt, url: String?
    let useSquashPRTitleAsDefault: Bool?
    let visibility: String?
    let watchersCount: Int?

    enum CodingKeys: String, CodingKey {
        case allowAutoMerge
        case allowMergeCommit
        case allowRebaseMerge
        case allowSquashMerge
        case allowUpdateBranch
        case archiveURL
        case archived
        case assigneesURL
        case blobsURL
        case branchesURL
        case cloneURL
        case collaboratorsURL
        case commentsURL
        case commitsURL
        case compareURL
        case contentsURL
        case contributorsURL
        case createdAt
        case defaultBranch
        case deleteBranchOnMerge
        case deploymentsURL
        case description, disabled
        case downloadsURL
        case eventsURL
        case fork
        case forksCount
        case forksURL
        case fullName
        case gitCommitsURL
        case gitRefsURL
        case gitTagsURL
        case gitURL
        case hasDownloads
        case hasIssues
        case hasPages
        case hasProjects
        case hasWiki
        case homepage
        case hooksURL
        case htmlURL
        case id
        case isTemplate
        case issueCommentURL
        case issueEventsURL
        case issuesURL
        case keysURL
        case labelsURL
        case language
        case languagesURL
        case mergeCommitMessage
        case mergeCommitTitle
        case mergesURL
        case milestonesURL
        case mirrorURL
        case name
        case networkCount
        case nodeID
        case notificationsURL
        case openIssuesCount
        case owner, permissions
        case templateRepositoryPrivate
        case pullsURL
        case pushedAt
        case releasesURL
        case size
        case squashMergeCommitMessage
        case squashMergeCommitTitle
        case sshURL
        case stargazersCount
        case stargazersURL
        case statusesURL
        case subscribersCount
        case subscribersURL
        case subscriptionURL
        case svnURL
        case tagsURL
        case teamsURL
        case tempCloneToken
        case topics
        case treesURL
        case updatedAt
        case url
        case useSquashPRTitleAsDefault
        case visibility
        case watchersCount
    }
}

// MARK: - FluffyOwner
struct FluffyOwner: Codable {
    let avatarURL, eventsURL, followersURL, followingURL: String?
    let gistsURL, gravatarID, htmlURL: String?
    let id: Int?
    let login, nodeID, organizationsURL, receivedEventsURL: String?
    let reposURL: String?
    let siteAdmin: Bool?
    let starredURL, subscriptionsURL, type, url: String?

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

// MARK: - TentacledPermissions
struct TentacledPermissions: Codable {
    let admin, maintain, pull, push: Bool?
    let triage: Bool?
}

/// A repository on GitHub.
// MARK: - RepositoryClass
struct RepositoryClass: Codable {
    /// Whether to allow Auto-merge to be used on pull requests.
    let allowAutoMerge: Bool?
    /// Whether to allow forking this repo
    let allowForking: Bool?
    /// Whether to allow merge commits for pull requests.
    let allowMergeCommit: Bool?
    /// Whether to allow rebase merges for pull requests.
    let allowRebaseMerge: Bool?
    /// Whether to allow squash merges for pull requests.
    let allowSquashMerge: Bool?
    /// Whether or not a pull request head branch that is behind its base branch can always be
    /// updated even if it is not required to be up to date before merging.
    let allowUpdateBranch: Bool?
    /// Whether anonymous git access is enabled for this repository
    let anonymousAccessEnabled: Bool?
    let archiveURL: String
    /// Whether the repository is archived.
    let archived: Bool
    let assigneesURL, blobsURL, branchesURL, cloneURL: String
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String
    let contentsURL, contributorsURL: String
    let createdAt: Date?
    /// The default branch of the repository.
    let defaultBranch: String
    /// Whether to delete head branches when pull requests are merged
    let deleteBranchOnMerge: Bool?
    let deploymentsURL: String
    let description: String?
    /// Returns whether or not this repository disabled.
    let disabled: Bool
    let downloadsURL, eventsURL: String
    let fork: Bool
    let forks, forksCount: Int
    let forksURL, fullName, gitCommitsURL, gitRefsURL: String
    let gitTagsURL, gitURL: String
    /// Whether discussions are enabled.
    let hasDiscussions: Bool?
    /// Whether downloads are enabled.
    let hasDownloads: Bool
    /// Whether issues are enabled.
    let hasIssues: Bool
    let hasPages: Bool
    /// Whether projects are enabled.
    let hasProjects: Bool
    /// Whether the wiki is enabled.
    let hasWiki: Bool
    let homepage: String?
    let hooksURL, htmlURL: String
    /// Unique identifier of the repository
    let id: Int
    /// Whether this repository acts as a template that can be used to generate new repositories.
    let isTemplate: Bool?
    let issueCommentURL, issueEventsURL, issuesURL, keysURL: String
    let labelsURL: String
    let language: String?
    let languagesURL: String
    let license: FluffyLicenseSimple?
    let masterBranch: String?
    /// The default value for a merge commit message.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `PR_BODY` - default to the pull request's body.
    /// - `BLANK` - default to a blank commit message.
    let mergeCommitMessage: MergeCommitMessage?
    /// The default value for a merge commit title.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
    /// request #123 from branch-name).
    let mergeCommitTitle: MergeCommitTitle?
    let mergesURL, milestonesURL: String
    let mirrorURL: String?
    /// The name of the repository.
    let name: String
    let networkCount: Int?
    let nodeID, notificationsURL: String
    let openIssues, openIssuesCount: Int
    let organization: FluffySimpleUser?
    /// A GitHub user.
    let owner: StickySimpleUser
    let permissions: StickyPermissions?
    /// Whether the repository is private or public.
    let repositoryPrivate: Bool
    let pullsURL: String
    let pushedAt: Date?
    let releasesURL: String
    /// The size of the repository. Size is calculated hourly. When a repository is initially
    /// created, the size is 0.
    let size: Int
    /// The default value for a squash merge commit message:
    ///
    /// - `PR_BODY` - default to the pull request's body.
    /// - `COMMIT_MESSAGES` - default to the branch's commit messages.
    /// - `BLANK` - default to a blank commit message.
    let squashMergeCommitMessage: SquashMergeCommitMessage?
    /// The default value for a squash merge commit title:
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
    /// request's title (when more than one commit).
    let squashMergeCommitTitle: SquashMergeCommitTitle?
    let sshURL: String
    let stargazersCount: Int
    let stargazersURL: String
    let starredAt: String?
    let statusesURL: String
    let subscribersCount: Int?
    let subscribersURL, subscriptionURL, svnURL, tagsURL: String
    let teamsURL: String
    let tempCloneToken: String?
    let templateRepository: RepositoryTemplateRepository?
    let topics: [String]?
    let treesURL: String
    let updatedAt: Date?
    let url: String
    /// Whether a squash merge commit can use the pull request title as default. **This property
    /// has been deprecated. Please use `squash_merge_commit_title` instead.
    let useSquashPRTitleAsDefault: Bool?
    /// The repository visibility: public, private, or internal.
    let visibility: String?
    let watchers, watchersCount: Int
    /// Whether to require contributors to sign off on web-based commits
    let webCommitSignoffRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case allowAutoMerge
        case allowForking
        case allowMergeCommit
        case allowRebaseMerge
        case allowSquashMerge
        case allowUpdateBranch
        case anonymousAccessEnabled
        case archiveURL
        case archived
        case assigneesURL
        case blobsURL
        case branchesURL
        case cloneURL
        case collaboratorsURL
        case commentsURL
        case commitsURL
        case compareURL
        case contentsURL
        case contributorsURL
        case createdAt
        case defaultBranch
        case deleteBranchOnMerge
        case deploymentsURL
        case description, disabled
        case downloadsURL
        case eventsURL
        case fork, forks
        case forksCount
        case forksURL
        case fullName
        case gitCommitsURL
        case gitRefsURL
        case gitTagsURL
        case gitURL
        case hasDiscussions
        case hasDownloads
        case hasIssues
        case hasPages
        case hasProjects
        case hasWiki
        case homepage
        case hooksURL
        case htmlURL
        case id
        case isTemplate
        case issueCommentURL
        case issueEventsURL
        case issuesURL
        case keysURL
        case labelsURL
        case language
        case languagesURL
        case license
        case masterBranch
        case mergeCommitMessage
        case mergeCommitTitle
        case mergesURL
        case milestonesURL
        case mirrorURL
        case name
        case networkCount
        case nodeID
        case notificationsURL
        case openIssues
        case openIssuesCount
        case organization, owner, permissions
        case repositoryPrivate
        case pullsURL
        case pushedAt
        case releasesURL
        case size
        case squashMergeCommitMessage
        case squashMergeCommitTitle
        case sshURL
        case stargazersCount
        case stargazersURL
        case starredAt
        case statusesURL
        case subscribersCount
        case subscribersURL
        case subscriptionURL
        case svnURL
        case tagsURL
        case teamsURL
        case tempCloneToken
        case templateRepository
        case topics
        case treesURL
        case updatedAt
        case url
        case useSquashPRTitleAsDefault
        case visibility, watchers
        case watchersCount
        case webCommitSignoffRequired
    }
}

/// License Simple
// MARK: - FluffyLicenseSimple
struct FluffyLicenseSimple: Codable {
    let htmlURL: String?
    let key, name, nodeID: String
    let spdxID, url: String?

    enum CodingKeys: String, CodingKey {
        case htmlURL
        case key, name
        case nodeID
        case spdxID
        case url
    }
}

/// A GitHub user.
// MARK: - FluffySimpleUser
struct FluffySimpleUser: Codable {
    let avatarURL: String
    let email: String?
    let eventsURL, followersURL, followingURL, gistsURL: String
    let gravatarID: String?
    let htmlURL: String
    let id: Int
    let login: String
    let name: String?
    let nodeID, organizationsURL, receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredAt: String?
    let starredURL, subscriptionsURL, type, url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case email
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login, name
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredAt
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

/// A GitHub user.
// MARK: - StickySimpleUser
struct StickySimpleUser: Codable {
    let avatarURL: String
    let email: String?
    let eventsURL, followersURL, followingURL, gistsURL: String
    let gravatarID: String?
    let htmlURL: String
    let id: Int
    let login: String
    let name: String?
    let nodeID, organizationsURL, receivedEventsURL, reposURL: String
    let siteAdmin: Bool
    let starredAt: String?
    let starredURL, subscriptionsURL, type, url: String

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case email
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login, name
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredAt
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

// MARK: - StickyPermissions
struct StickyPermissions: Codable {
    let admin: Bool
    let maintain: Bool?
    let pull, push: Bool
    let triage: Bool?
}

// MARK: - RepositoryTemplateRepository
struct RepositoryTemplateRepository: Codable {
    let allowAutoMerge, allowMergeCommit, allowRebaseMerge, allowSquashMerge: Bool?
    let allowUpdateBranch: Bool?
    let archiveURL: String?
    let archived: Bool?
    let assigneesURL, blobsURL, branchesURL, cloneURL: String?
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String?
    let contentsURL, contributorsURL, createdAt, defaultBranch: String?
    let deleteBranchOnMerge: Bool?
    let deploymentsURL, description: String?
    let disabled: Bool?
    let downloadsURL, eventsURL: String?
    let fork: Bool?
    let forksCount: Int?
    let forksURL, fullName, gitCommitsURL, gitRefsURL: String?
    let gitTagsURL, gitURL: String?
    let hasDownloads, hasIssues, hasPages, hasProjects: Bool?
    let hasWiki: Bool?
    let homepage, hooksURL, htmlURL: String?
    let id: Int?
    let isTemplate: Bool?
    let issueCommentURL, issueEventsURL, issuesURL, keysURL: String?
    let labelsURL, language, languagesURL: String?
    /// The default value for a merge commit message.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `PR_BODY` - default to the pull request's body.
    /// - `BLANK` - default to a blank commit message.
    let mergeCommitMessage: MergeCommitMessage?
    /// The default value for a merge commit title.
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `MERGE_MESSAGE` - default to the classic title for a merge message (e.g., Merge pull
    /// request #123 from branch-name).
    let mergeCommitTitle: MergeCommitTitle?
    let mergesURL, milestonesURL, mirrorURL, name: String?
    let networkCount: Int?
    let nodeID, notificationsURL: String?
    let openIssuesCount: Int?
    let owner: TentacledOwner?
    let permissions: IndigoPermissions?
    let templateRepositoryPrivate: Bool?
    let pullsURL, pushedAt, releasesURL: String?
    let size: Int?
    /// The default value for a squash merge commit message:
    ///
    /// - `PR_BODY` - default to the pull request's body.
    /// - `COMMIT_MESSAGES` - default to the branch's commit messages.
    /// - `BLANK` - default to a blank commit message.
    let squashMergeCommitMessage: SquashMergeCommitMessage?
    /// The default value for a squash merge commit title:
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
    /// request's title (when more than one commit).
    let squashMergeCommitTitle: SquashMergeCommitTitle?
    let sshURL: String?
    let stargazersCount: Int?
    let stargazersURL, statusesURL: String?
    let subscribersCount: Int?
    let subscribersURL, subscriptionURL, svnURL, tagsURL: String?
    let teamsURL, tempCloneToken: String?
    let topics: [String]?
    let treesURL, updatedAt, url: String?
    let useSquashPRTitleAsDefault: Bool?
    let visibility: String?
    let watchersCount: Int?

    enum CodingKeys: String, CodingKey {
        case allowAutoMerge
        case allowMergeCommit
        case allowRebaseMerge
        case allowSquashMerge
        case allowUpdateBranch
        case archiveURL
        case archived
        case assigneesURL
        case blobsURL
        case branchesURL
        case cloneURL
        case collaboratorsURL
        case commentsURL
        case commitsURL
        case compareURL
        case contentsURL
        case contributorsURL
        case createdAt
        case defaultBranch
        case deleteBranchOnMerge
        case deploymentsURL
        case description, disabled
        case downloadsURL
        case eventsURL
        case fork
        case forksCount
        case forksURL
        case fullName
        case gitCommitsURL
        case gitRefsURL
        case gitTagsURL
        case gitURL
        case hasDownloads
        case hasIssues
        case hasPages
        case hasProjects
        case hasWiki
        case homepage
        case hooksURL
        case htmlURL
        case id
        case isTemplate
        case issueCommentURL
        case issueEventsURL
        case issuesURL
        case keysURL
        case labelsURL
        case language
        case languagesURL
        case mergeCommitMessage
        case mergeCommitTitle
        case mergesURL
        case milestonesURL
        case mirrorURL
        case name
        case networkCount
        case nodeID
        case notificationsURL
        case openIssuesCount
        case owner, permissions
        case templateRepositoryPrivate
        case pullsURL
        case pushedAt
        case releasesURL
        case size
        case squashMergeCommitMessage
        case squashMergeCommitTitle
        case sshURL
        case stargazersCount
        case stargazersURL
        case statusesURL
        case subscribersCount
        case subscribersURL
        case subscriptionURL
        case svnURL
        case tagsURL
        case teamsURL
        case tempCloneToken
        case topics
        case treesURL
        case updatedAt
        case url
        case useSquashPRTitleAsDefault
        case visibility
        case watchersCount
    }
}

// MARK: - TentacledOwner
struct TentacledOwner: Codable {
    let avatarURL, eventsURL, followersURL, followingURL: String?
    let gistsURL, gravatarID, htmlURL: String?
    let id: Int?
    let login, nodeID, organizationsURL, receivedEventsURL: String?
    let reposURL: String?
    let siteAdmin: Bool?
    let starredURL, subscriptionsURL, type, url: String?

    enum CodingKeys: String, CodingKey {
        case avatarURL
        case eventsURL
        case followersURL
        case followingURL
        case gistsURL
        case gravatarID
        case htmlURL
        case id, login
        case nodeID
        case organizationsURL
        case receivedEventsURL
        case reposURL
        case siteAdmin
        case starredURL
        case subscriptionsURL
        case type, url
    }
}

// MARK: - IndigoPermissions
struct IndigoPermissions: Codable {
    let admin, maintain, pull, push: Bool?
    let triage: Bool?
}
