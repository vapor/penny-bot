@testable import PennyBOT
import PennyModels

public struct FakeProposalsService: ProposalsService {

    public init() { }

    public func list() async throws -> [Proposal] {
        TestData.proposalsUpdated
    }

    public func getProposalContent(link: String) async throws -> String {
        TestData.proposalContent
    }
}
