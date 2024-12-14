import EvolutionMetadataModel
import Models

@testable import Penny

struct FakeEvolutionService: EvolutionService {

    init() {}

    func list() async throws -> [Proposal] {
        TestData.proposalsUpdated
    }

    func getProposalContent(link: String) async throws -> String {
        TestData.proposalContent
    }
}
