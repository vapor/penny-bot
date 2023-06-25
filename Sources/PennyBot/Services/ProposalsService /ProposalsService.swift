import PennyModels

protocol ProposalsService: Sendable {
    func list() async throws -> [Proposal]
    func getProposalContent(link: String) async throws -> String
}
