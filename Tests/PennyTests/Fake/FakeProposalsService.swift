@testable import Penny
import Models

package struct FakeEvolutionService: EvolutionService {

    package init() { }

    package func list() async throws -> [Proposal] {
        TestData.proposalsUpdated
    }

    package func getProposalContent(link: String) async throws -> String {
        TestData.proposalContent
    }
}
