
/// The default value for a merge commit message.
enum MergeCommitMessage: String, Codable {
    case blank = "BLANK"
    case prBody = "PR_BODY"
    case prTitle = "PR_TITLE"
    case commitMessages = "COMMIT_MESSAGES"
}

/// The default value for a merge commit title.
enum MergeCommitTitle: String, Codable {
    case mergeMessage = "MERGE_MESSAGE"
    case prTitle = "PR_TITLE"
}
