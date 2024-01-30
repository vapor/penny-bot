import Models

protocol EvolutionService: Sendable {
    func list() async throws -> [Proposal]
    func getProposalContent(link: String) async throws -> String
}
