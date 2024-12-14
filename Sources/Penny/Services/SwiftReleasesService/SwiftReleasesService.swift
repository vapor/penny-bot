protocol SwiftReleasesService: Sendable {
    func listReleases() async throws -> [SwiftOrgRelease]
}
