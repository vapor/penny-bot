import DiscordBM
import Logging
import Markdown
import NewCodable
import ServiceLifecycle
import Shared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

actor SOChecker: Service {

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

    func run() async throws {
        switch Constants.deploymentEnvironment {
        case .testing, .local: break
        case .prod:
            /// Cloudflare seems to be blocking us although we have an auth token.
            /// Waits forever:
            let (stream, _) = AsyncStream.makeStream(of: Void.self)
            await stream.first { _ in true }
            return
        /// Just in case
        }
        if Task.isCancelled { return }
        do {
            try await self.check()
        } catch {
            logger.report("Couldn't check SO questions", error: error)
        }
        try await Task.sleep(for: .seconds(60 * 5))
        /// 5 mins
        try await self.run()
    }

    func check() async throws {
        let after = storage.lastCheckDate ?? Date().addingTimeInterval(-60 * 60)
        let questions = try await soService.listQuestions(after: after)
        storage.lastCheckDate = Date()

        for question in questions {
            await discordService.sendMessage(
                channelId: Constants.Channels.stackOverflow.id,
                payload: .init(embeds: [
                    .init(
                        title: question.title.htmlDecoded().unicodesPrefix(256),
                        url: question.link,
                        timestamp: Date(timeIntervalSince1970: Double(question.creationDate)),
                        color: .mint,
                        footer: .init(
                            text: "By \(question.owner.displayName)",
                            icon_url: question.owner.profileImage.map { .exact($0) }
                        )
                    )
                ])
            )
        }
    }

    func consumeCachesStorageData(_ storage: Storage) {
        self.storage = storage
    }

    func getCachedDataForCachesStorage() -> Storage {
        self.storage
    }
}

// MARK: +String
extension String {
    fileprivate func htmlDecoded() -> String {
        Document(parsing: self).format()
    }
}

// MARK: - SOQuestions
@JSONCodable
struct SOQuestions {

    @JSONCodable
    struct Item {

        @JSONCodable
        struct Owner {
            @CodingKey("account_id")
            let accountID: Int?
            let reputation: Int?
            @CodingKey("user_id")
            let userID: Int?
            @CodingKey("user_type")
            let userType: String
            @CodingKey("accept_rate")
            let acceptRate: Int?
            @CodingKey("profile_image")
            let profileImage: String?
            @CodingKey("display_name")
            let displayName: String
            let link: String?
        }

        let tags: [String]
        let owner: Owner
        @CodingKey("is_answered")
        let isAnswered: Bool
        @CodingKey("view_count")
        let viewCount: Int
        @CodingKey("accepted_answer_id")
        let acceptedAnswerID: Int?
        @CodingKey("answer_count")
        let answerCount: Int
        let score: Int
        @CodingKey("last_activity_date")
        let lastActivityDate: Int
        @CodingKey("creation_date")
        let creationDate: Int
        @CodingKey("question_id")
        let questionID: Int
        @CodingKey("content_license")
        let contentLicense: String?
        let link: String
        let title: String
        @CodingKey("last_edit_date")
        let lastEditDate: Int?
        @CodingKey("closed_date")
        let closedDate: Int?
        @CodingKey("closed_reason")
        let closedReason: String?
    }

    let items: [Item]
    @CodingKey("has_more")
    let hasMore: Bool
    @CodingKey("quota_max")
    let quotaMax: Int
    @CodingKey("quota_remaining")
    let quotaRemaining: Int
}
