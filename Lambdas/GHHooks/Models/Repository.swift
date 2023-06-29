import Foundation

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
    let codeOfConduct: CodeOfConduct?
    let collaboratorsURL, commentsURL, commitsURL, compareURL: String
    let contentsURL, contributorsURL: String
    let createdAt: Date?
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
    let networkCount: Int?
    let nodeID, notificationsURL: String
    let openIssues, openIssuesCount: Int
    let organization: User?
    /// A GitHub user.
    let owner: User
    /// A repository on GitHub.
    let parent: DereferenceBox<Repository>?
    let permissions: Permissions?
    let repositoryPrivate: Bool
    let pullsURL: String
    let pushedAt: Date
    let releasesURL: String
    let securityAndAnalysis: SecurityAndAnalysis?
    /// The size of the repository. Size is calculated hourly. When a repository is initially
    /// created, the size is 0.
    let size: Int
    /// A repository on GitHub.
    let source: DereferenceBox<Repository>?
    /// The default value for a squash merge commit message:
    ///
    /// - `PR_BODY` - default to the pull request's body.
    /// - `COMMIT_MESSAGES` - default to the branch's commit messages.
    /// - `BLANK` - default to a blank commit message.
    let squashMergeCommitMessage: MergeCommitMessage?
    /// The default value for a squash merge commit title:
    ///
    /// - `PR_TITLE` - default to the pull request's title.
    /// - `COMMIT_OR_PR_TITLE` - default to the commit's title (if only one commit) or the pull
    /// request's title (when more than one commit).
    let squashMergeCommitTitle: MergeCommitTitle?
    let sshURL: String
    let stargazersCount: Int
    let stargazersURL, statusesURL: String
    let subscribersCount: Int?
    let subscribersURL, subscriptionURL, svnURL, tagsURL: String
    let teamsURL: String
    let tempCloneToken: String?
    let templateRepository: DereferenceBox<Repository>?
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
        case allowAutoMerge = "allow_auto_merge"
        case allowForking = "allow_forking"
        case allowMergeCommit = "allow_merge_commit"
        case allowRebaseMerge = "allow_rebase_merge"
        case allowSquashMerge = "allow_squash_merge"
        case allowUpdateBranch = "allow_update_branch"
        case anonymousAccessEnabled = "anonymous_access_enabled"
        case archiveURL = "archive_url"
        case archived
        case assigneesURL = "assignees_url"
        case blobsURL = "blobs_url"
        case branchesURL = "branches_url"
        case cloneURL = "clone_url"
        case codeOfConduct = "code_of_conduct"
        case collaboratorsURL = "collaborators_url"
        case commentsURL = "comments_url"
        case commitsURL = "commits_url"
        case compareURL = "compare_url"
        case contentsURL = "contents_url"
        case contributorsURL = "contributors_url"
        case createdAt = "created_at"
        case defaultBranch = "default_branch"
        case deleteBranchOnMerge = "delete_branch_on_merge"
        case deploymentsURL = "deployments_url"
        case description, disabled
        case downloadsURL = "downloads_url"
        case eventsURL = "events_url"
        case fork, forks
        case forksCount = "forks_count"
        case forksURL = "forks_url"
        case fullName = "full_name"
        case gitCommitsURL = "git_commits_url"
        case gitRefsURL = "git_refs_url"
        case gitTagsURL = "git_tags_url"
        case gitURL = "git_url"
        case hasDiscussions = "has_discussions"
        case hasDownloads = "has_downloads"
        case hasIssues = "has_issues"
        case hasPages = "has_pages"
        case hasProjects = "has_projects"
        case hasWiki = "has_wiki"
        case homepage
        case hooksURL = "hooks_url"
        case htmlURL = "html_url"
        case id
        case isTemplate = "is_template"
        case issueCommentURL = "issue_comment_url"
        case issueEventsURL = "issue_events_url"
        case issuesURL = "issues_url"
        case keysURL = "keys_url"
        case labelsURL = "labels_url"
        case language
        case languagesURL = "languages_url"
        case license
        case masterBranch = "master_branch"
        case mergeCommitMessage = "merge_commit_message"
        case mergeCommitTitle = "merge_commit_title"
        case mergesURL = "merges_url"
        case milestonesURL = "milestones_url"
        case mirrorURL = "mirror_url"
        case name
        case networkCount = "network_count"
        case nodeID = "node_id"
        case notificationsURL = "notifications_url"
        case openIssues = "open_issues"
        case openIssuesCount = "open_issues_count"
        case organization, owner, parent, permissions
        case repositoryPrivate = "private"
        case pullsURL = "pulls_url"
        case pushedAt = "pushed_at"
        case releasesURL = "releases_url"
        case securityAndAnalysis = "security_and_analysis"
        case size, source
        case squashMergeCommitMessage = "squash_merge_commit_message"
        case squashMergeCommitTitle = "squash_merge_commit_title"
        case sshURL = "ssh_url"
        case stargazersCount = "stargazers_count"
        case stargazersURL = "stargazers_url"
        case statusesURL = "statuses_url"
        case subscribersCount = "subscribers_count"
        case subscribersURL = "subscribers_url"
        case subscriptionURL = "subscription_url"
        case svnURL = "svn_url"
        case tagsURL = "tags_url"
        case teamsURL = "teams_url"
        case tempCloneToken = "temp_clone_token"
        case templateRepository = "template_repository"
        case topics
        case treesURL = "trees_url"
        case updatedAt = "updated_at"
        case url
        case useSquashPRTitleAsDefault = "use_squash_pr_title_as_default"
        case visibility, watchers
        case watchersCount = "watchers_count"
        case webCommitSignoffRequired = "web_commit_signoff_required"
    }

    // MARK: - CodeOfConduct
    struct CodeOfConduct: Codable {
        let htmlURL: String?
        let key, name, url: String

        enum CodingKeys: String, CodingKey {
            case htmlURL = "html_url"
            case key, name, url
        }
    }

    // MARK: - PurpleLicenseSimple
    struct PurpleLicenseSimple: Codable {
        let htmlURL: String?
        let key, name, nodeID: String
        let spdxID, url: String?

        enum CodingKeys: String, CodingKey {
            case htmlURL = "html_url"
            case key, name
            case nodeID = "node_id"
            case spdxID = "spdx_id"
            case url
        }
    }
}

