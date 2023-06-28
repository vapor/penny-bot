import Foundation

struct GithubEvent: Codable {
    /// Name will be populated after decode
    public var name: String!
    public var action: String?
    public var sender: User
    public var repository: Repository
    public var organization: Organization
}


// MARK: - Repository
struct Repository: Codable {
    let id: Int
    let nodeID, name, fullName: String
    let owner: User
    let userPrivate: Bool
    let htmlURL: String
    let description: String
    let fork: Bool
    let url: String
    let archiveURL, assigneesURL, blobsURL, branchesURL: String
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String
    let contentsURL: String
    let contributorsURL, deploymentsURL, downloadsURL, eventsURL: String
    let forksURL: String
    let gitCommitsURL, gitRefsURL, gitTagsURL, gitURL: String
    let issueCommentURL, issueEventsURL, issuesURL, keysURL: String
    let labelsURL: String
    let languagesURL, mergesURL: String
    let milestonesURL, notificationsURL, pullsURL, releasesURL: String
    let sshURL: String
    let stargazersURL: String
    let statusesURL: String
    let subscribersURL, subscriptionURL, tagsURL, teamsURL: String
    let treesURL: String
    let cloneURL: String
    let mirrorURL: String
    let hooksURL, svnURL, homepage: String
    let language: String?
    let forksCount, forks, stargazersCount, watchersCount: Int
    let watchers, size: Int
    let defaultBranch: String
    let openIssuesCount, openIssues: Int
    let isTemplate: Bool
    let topics: [String]
    let hasIssues, hasProjects, hasWiki, hasPages: Bool
    let hasDownloads, hasDiscussions, archived, disabled: Bool
    let visibility: String
    let pushedAt, createdAt, updatedAt: Date
    let permissions: Permissions
    let allowRebaseMerge: Bool
    let templateRepository: DereferenceBox<Repository>
    let tempCloneToken: String
    let allowSquashMerge, allowAutoMerge, deleteBranchOnMerge, allowMergeCommit: Bool
    let subscribersCount, networkCount: Int
    let license: License
    let organization: Organization
    let parent, source: DereferenceBox<Repository>

    enum CodingKeys: String, CodingKey {
        case id
        case nodeID
        case name
        case fullName
        case owner
        case userPrivate
        case htmlURL
        case description, fork, url
        case archiveURL
        case assigneesURL
        case blobsURL
        case branchesURL
        case collaboratorsURL
        case commentsURL
        case commitsURL
        case compareURL
        case contentsURL
        case contributorsURL
        case deploymentsURL
        case downloadsURL
        case eventsURL
        case forksURL
        case gitCommitsURL
        case gitRefsURL
        case gitTagsURL
        case gitURL
        case issueCommentURL
        case issueEventsURL
        case issuesURL
        case keysURL
        case labelsURL
        case languagesURL
        case mergesURL
        case milestonesURL
        case notificationsURL
        case pullsURL
        case releasesURL
        case sshURL
        case stargazersURL
        case statusesURL
        case subscribersURL
        case subscriptionURL
        case tagsURL
        case teamsURL
        case treesURL
        case cloneURL
        case mirrorURL
        case hooksURL
        case svnURL
        case homepage, language
        case forksCount
        case forks
        case stargazersCount
        case watchersCount
        case watchers, size
        case defaultBranch
        case openIssuesCount
        case openIssues
        case isTemplate
        case topics
        case hasIssues
        case hasProjects
        case hasWiki
        case hasPages
        case hasDownloads
        case hasDiscussions
        case archived, disabled, visibility
        case pushedAt
        case createdAt
        case updatedAt
        case permissions
        case allowRebaseMerge
        case templateRepository
        case tempCloneToken
        case allowSquashMerge
        case allowAutoMerge
        case deleteBranchOnMerge
        case allowMergeCommit
        case subscribersCount
        case networkCount
        case license, organization, parent, source
    }
}

// MARK: - License
struct License: Codable {
    let key, name, spdxID: String
    let url: String
    let nodeID: String
    let htmlURL: String?

    enum CodingKeys: String, CodingKey {
        case key, name
        case spdxID
        case url
        case nodeID
        case htmlURL
    }
}

// MARK: - Organization
struct Organization: Codable {
    let login: String
    let id: Int
    let nodeID: String
    let avatarURL: String
    let gravatarID: String
    let url, htmlURL, followersURL: String
    let followingURL, gistsURL, starredURL: String
    let subscriptionsURL, organizationsURL, reposURL: String
    let eventsURL: String
    let receivedEventsURL: String
    let type: String
    let siteAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case login, id
        case nodeID
        case avatarURL
        case gravatarID
        case url
        case htmlURL
        case followersURL
        case followingURL
        case gistsURL
        case starredURL
        case subscriptionsURL
        case organizationsURL
        case reposURL
        case eventsURL
        case receivedEventsURL
        case type
        case siteAdmin
    }
}

// MARK: - Permissions
struct Permissions: Codable {
    let pull, push, admin: Bool
}

// MARK: - SecurityAndAnalysis
struct SecurityAndAnalysis: Codable {
    let advancedSecurity, secretScanning, secretScanningPushProtection: AdvancedSecurity

    enum CodingKeys: String, CodingKey {
        case advancedSecurity
        case secretScanning
        case secretScanningPushProtection
    }
}

// MARK: - AdvancedSecurity
struct AdvancedSecurity: Codable {
    let status: String
}

// MARK: - User
struct User: Codable {
    let login: String
    let id: Int
    let nodeID: String
    let avatarURL: String
    let gravatarID: String
    let url, htmlURL, followersURL: String
    let followingURL, gistsURL, starredURL: String
    let subscriptionsURL, organizationsURL, reposURL: String
    let eventsURL: String
    let receivedEventsURL: String
    let type: String
    let siteAdmin: Bool
    let name, company: String
    let blog: String
    let location, email: String
    let hireable: Bool
    let bio, twitterUsername: String
    let publicRepos, publicGists, followers, following: Int
    let createdAt, updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case login, id
        case nodeID
        case avatarURL
        case gravatarID
        case url
        case htmlURL
        case followersURL
        case followingURL
        case gistsURL
        case starredURL
        case subscriptionsURL
        case organizationsURL
        case reposURL
        case eventsURL
        case receivedEventsURL
        case type
        case siteAdmin
        case name, company, blog, location, email, hireable, bio
        case twitterUsername
        case publicRepos
        case publicGists
        case followers, following
        case createdAt
        case updatedAt
    }
}

//MARK: - DereferenceBox
final class DereferenceBox<C: Codable>: Codable {
    var value: C

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(C.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
}
