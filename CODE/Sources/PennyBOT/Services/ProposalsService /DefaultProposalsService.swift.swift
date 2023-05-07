import AsyncHTTPClient
import PennyModels
import NIOCore
import Foundation

struct DefaultProposalsService: ProposalsService {
    
    enum Error: Swift.Error {
        case emptyProposals
    }

    let httpClient: HTTPClient

    func get() async throws -> [Proposal] {
        let response = try await httpClient.execute(
            .init(url: "https://download.swift.org/swift-evolution/proposals.json"),
            deadline: .now() + .seconds(5)
        )
        let buffer = try await response.body.collect(upTo: 1 << 23) /// 8 MB
        let decoder = JSONDecoder()
        let proposals = try decoder.decode([Proposal].self, from: buffer)
        if proposals.isEmpty {
            throw Error.emptyProposals
        }
        return proposals
    }
}
