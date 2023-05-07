import PennyModels

protocol ProposalsService {
    func get() async throws -> [Proposal]
}
