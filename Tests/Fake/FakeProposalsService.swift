@testable import Penny
import Models

public struct FakeEvolutionService: EvolutionService {

    public init() { }

    public func list() async throws -> [Proposal] {
        TestData.proposalsUpdated
    }

    public func getProposalContent(link: String) async throws -> String {
        TestData.proposalContent
    }
}
