@testable import PennyBOT
import PennyModels

public struct FakeProposalsService: ProposalsService {

    public init() { }

    public func get() async throws -> [Proposal] {
        TestData.proposalsUpdated
    }
}
