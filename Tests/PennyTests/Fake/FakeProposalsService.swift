@testable import Penny
import Models
import EvolutionMetadataModel

struct FakeEvolutionService: EvolutionService {

    init() { }

    func list() async throws -> [Proposal] {
        TestData.proposalsUpdated
    }

    func getProposalContent(link: String) async throws -> String {
        TestData.proposalContent
    }
}
