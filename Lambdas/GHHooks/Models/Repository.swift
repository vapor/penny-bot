import Foundation

// MARK: - Repository
struct Repository: Codable {
    let id: Int
    let nodeID: String?
    let name: String
    let fullName: String?
    let repositoryPrivate: Bool?
    let owner: User
    let htmlURL: String?
    let description: String
    let fork: Bool
    let url: String
    let forksURL: String?
    let keysURL: String?
    let collaboratorsURL: String?
    let teamsURL: String?
    let hooksURL: String?
    let issueEventsURL: String?
    let eventsURL: String?
    let assigneesURL: String?
    let branchesURL: String?
    let tagsURL: String?
    let blobsURL, gitTagsURL, gitRefsURL, treesURL: String?
    let statusesURL: String?
    let languagesURL, stargazersURL, contributorsURL, subscribersURL: String?
    let subscriptionURL: String?
    let commitsURL, gitCommitsURL, commentsURL, issueCommentURL: String?
    let contentsURL, compareURL: String?
    let mergesURL: String?
    let archiveURL: String?
    let downloadsURL: String?
    let issuesURL, pullsURL, milestonesURL, notificationsURL: String?
    let labelsURL, releasesURL: String?
    let deploymentsURL: String?
    let createdAt, updatedAt, pushedAt: Date?
    let gitURL, sshURL: String?
    let cloneURL: String?
    let svnURL: String?
    let homepage: String
    let size: Int
    let stargazersCount: Int?
    let watchersCount: Int?
    let language: String
    let hasIssues, hasProjects, hasDownloads, hasWiki: Bool?
    let hasPages, hasDiscussions: Bool?
    let forksCount: Int?
    let mirrorURL: String?
    let archived, disabled: Bool
    let openIssuesCount: Int?
    let license: String?
    let allowForking, isTemplate, webCommitSignoffRequired: Bool?
    let topics: [String]
    let visibility: String
    let forks: Int
    let openIssues: Int?
    let watchers: Int
    let defaultBranch: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nodeID
        case name
        case fullName
        case repositoryPrivate
        case owner
        case htmlURL
        case description, fork, url
        case forksURL
        case keysURL
        case collaboratorsURL
        case teamsURL
        case hooksURL
        case issueEventsURL
        case eventsURL
        case assigneesURL
        case branchesURL
        case tagsURL
        case blobsURL
        case gitTagsURL
        case gitRefsURL
        case treesURL
        case statusesURL
        case languagesURL
        case stargazersURL
        case contributorsURL
        case subscribersURL
        case subscriptionURL
        case commitsURL
        case gitCommitsURL
        case commentsURL
        case issueCommentURL
        case contentsURL
        case compareURL
        case mergesURL
        case archiveURL
        case downloadsURL
        case issuesURL
        case pullsURL
        case milestonesURL
        case notificationsURL
        case labelsURL
        case releasesURL
        case deploymentsURL
        case createdAt
        case updatedAt
        case pushedAt
        case gitURL
        case sshURL
        case cloneURL
        case svnURL
        case homepage, size
        case stargazersCount
        case watchersCount
        case language
        case hasIssues
        case hasProjects
        case hasDownloads
        case hasWiki
        case hasPages
        case hasDiscussions
        case forksCount
        case mirrorURL
        case archived, disabled
        case openIssuesCount
        case license
        case allowForking
        case isTemplate
        case webCommitSignoffRequired
        case topics, visibility, forks
        case openIssues
        case watchers
        case defaultBranch
    }
}
