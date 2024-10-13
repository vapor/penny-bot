import Logging
import DiscordBM
import Collections
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

actor SwiftReleasesChecker {
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

    nonisolated func run() {
        Task { [self] in
            if Task.isCancelled { return }
            do {
                try await self.check()
            } catch {
                logger.report("Couldn't check Swift releases", error: error)
            }
            try await Task.sleep(for: .seconds(60 * 15)) /// 15 mins
            self.run()
        }
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
            let image = "https://opengraph.githubassets.com/\(UUID().uuidString)/swiftlang/swift/releases/tag/\(release.tag)"
            await discordService.sendMessage(
                channelId: Constants.Channels.release.id,
                payload: .init(embeds: [.init(
                    title: "Swift Release \(release.stableName)".unicodesPrefix(256),
                    url: "https://github.com/swiftlang/swift/releases/tag/\(release.tag)",
                    color: .green(scheme: .dark),
                    image: .init(url: .exact(image))
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

struct SwiftOrgRelease: Codable, Hashable {
    let name: String
    let tag: String

    var stableName: String {
        let components = self.name.components(separatedBy: ".")
        if components.count == 2 {
            return self.name + ".0"
        } else {
            return self.name
        }
    }
}
