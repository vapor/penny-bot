@testable import Penny

struct FakeSwiftReleasesService: SwiftReleasesService {

    func listReleases() async throws -> [SwiftOrgRelease] {
        TestData.swiftReleasesUpdated
    }
}
