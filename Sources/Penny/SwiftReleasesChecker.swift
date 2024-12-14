import Collections
import DiscordBM
import Logging
import ServiceLifecycle

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

actor SwiftReleasesChecker: Service {

    struct Storage: Sendable, Codable {
        var currentReleases: [SwiftOrgRelease] = []
    }

    var storage = Storage()

    let swiftReleasesService: any SwiftReleasesService
    let discordService: DiscordService
    let logger = Logger(label: "SwiftReleasesChecker")

    init(swiftReleasesService: any SwiftReleasesService, discordService: DiscordService) {
        self.swiftReleasesService = swiftReleasesService
        self.discordService = discordService
    }

    func run() async throws {
        if Task.isCancelled { return }
        do {
            try await self.check()
        } catch {
            logger.report("Couldn't check Swift releases", error: error)
        }
        try await Task.sleep(for: .seconds(60 * 15))
        /// 15 mins
        try await self.run()
    }

    private func check() async throws {
        let releases = try await swiftReleasesService.listReleases()

        if self.storage.currentReleases.isEmpty {
            self.storage.currentReleases = Array(releases)
            return
        }

        let newReleases = OrderedSet(releases).subtracting(self.storage.currentReleases)
        self.storage.currentReleases = releases

        for release in newReleases {
            /// swiftlang's GitHub logo aka the Swift logo
            let image = "https://avatars.githubusercontent.com/u/42816656"
            await discordService.sendMessage(
                channelId: Constants.Channels.news.id,
                payload: .init(embeds: [
                    .init(
                        title: "Swift \(release.stableName) Release".unicodesPrefix(256),
                        description: """
                            \((release.xcodeRelease == true) ? "Available on \(release.xcode)" : "Doesn't come with a dedicated Xcode release")
                            """,
                        url: "https://github.com/swiftlang/swift/releases/tag/\(release.tag)",
                        color: .orange,
                        image: .init(url: .exact(image))
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

struct SwiftOrgRelease: Codable {
    let name: String
    let tag: String
    let xcode: String
    let xcodeRelease: Bool?

    var stableName: String {
        let components = self.name.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        if components.count == 2 {
            return self.name + ".0"
        } else {
            return self.name
        }
    }
}

extension SwiftOrgRelease: Hashable {
    static func == (lhs: SwiftOrgRelease, rhs: SwiftOrgRelease) -> Bool {
        lhs.tag == rhs.tag
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.tag)
    }
}
