import PennyModels

protocol ProposalsService: Sendable {
    func get() async throws -> [Proposal]
}
