import LeafKit

struct NewReleaseContext: Codable {

    struct PR: Codable {
        let title: String
        let body: String
        let author: String
        let number: Int
    }

    struct Repo: Codable {
        let fullName: String
    }

    struct Release: Codable {
        let oldTag: String
        let newTag: String
    }

    let pr: PR
    let isNewContributor: Bool
    let reviewers: [String]
    let merged_by: String
    let repo: Repo
    let release: Release
}
