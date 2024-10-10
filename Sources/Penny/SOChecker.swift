import Logging
import DiscordBM
import Markdown
import Foundation

actor SOChecker {

    struct Storage: Sendable, Codable {
        var lastCheckDate: Date?
    }

    var storage = Storage()

    let soService: any SOService
    let discordService: DiscordService
    let logger = Logger(label: "SOChecker")

    init(soService: any SOService, discordService: DiscordService) {
        self.soService = soService
        self.discordService = discordService
    }

    nonisolated func run() {
        #if !DEBUG
        /// Cloudflare seems to be blocking us although we have an auth token.
        return
        #endif
        Task { [self] in
            if Task.isCancelled { return }
            do {
                try await self.check()
            } catch {
                logger.report("Couldn't check SO questions", error: error)
            }
            try await Task.sleep(for: .seconds(60 * 5)) /// 5 mins
            self.run()
        }
    }

    func check() async throws {
        let after = storage.lastCheckDate ?? Date().addingTimeInterval(-60 * 60)
        let questions = try await soService.listQuestions(after: after)
        storage.lastCheckDate = Date()

        for question in questions {
            await discordService.sendMessage(
                channelId: Constants.Channels.stackOverflow.id,
                payload: .init(embeds: [.init(
                    title: question.title.htmlDecoded().unicodesPrefix(256),
                    url: question.link,
                    timestamp: Date(timeIntervalSince1970: Double(question.creationDate)),
                    color: .mint,
                    footer: .init(
                        text: "By \(question.owner.displayName)",
                        icon_url: question.owner.profileImage.map { .exact($0) }
                    )
                )])
            )
        }
    }

    func consumeCachesStorageData(_ storage: Storage) {
        self.storage = storage
    }

    func getCachedDataForCachesStorage() -> Storage {
        return self.storage
    }
}

// MARK: +String
private extension String {
    func htmlDecoded() -> String {
        Document(parsing: self).format()
    }
}

// MARK: - SOQuestions
struct SOQuestions: Codable {

    struct Item: Codable {

        struct Owner: Codable {
            let accountID: Int?
            let reputation: Int?
            let userID: Int?
            let userType: String
            let acceptRate: Int?
            let profileImage: String?
            let displayName: String
            let link: String?

            enum CodingKeys: String, CodingKey {
                case accountID = "account_id"
                case reputation
                case userID = "user_id"
                case userType = "user_type"
                case acceptRate = "accept_rate"
                case profileImage = "profile_image"
                case displayName = "display_name"
                case link
            }
        }

        let tags: [String]
        let owner: Owner
        let isAnswered: Bool
        let viewCount: Int
        let acceptedAnswerID: Int?
        let answerCount: Int
        let score: Int
        let lastActivityDate: Int
        let creationDate: Int
        let questionID: Int
        let contentLicense: String?
        let link: String
        let title: String
        let lastEditDate: Int?
        let closedDate: Int?
        let closedReason: String?

        enum CodingKeys: String, CodingKey {
            case tags, owner
            case isAnswered = "is_answered"
            case viewCount = "view_count"
            case acceptedAnswerID = "accepted_answer_id"
            case answerCount = "answer_count"
            case score
            case lastActivityDate = "last_activity_date"
            case creationDate = "creation_date"
            case questionID = "question_id"
            case contentLicense = "content_license"
            case link, title
            case lastEditDate = "last_edit_date"
            case closedDate = "closed_date"
            case closedReason = "closed_reason"
        }
    }

    let items: [Item]
    let hasMore: Bool
    let quotaMax: Int
    let quotaRemaining: Int

    enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
        case quotaMax = "quota_max"
        case quotaRemaining = "quota_remaining"
    }
}
