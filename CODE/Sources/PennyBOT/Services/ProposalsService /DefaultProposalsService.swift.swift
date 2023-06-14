import AsyncHTTPClient
import PennyModels
import NIOCore
import Foundation

struct DefaultProposalsService: ProposalsService {
    
    enum Error: Swift.Error {
        case emptyProposals
    }

    let httpClient: HTTPClient
    let decoder = JSONDecoder()

    func list() async throws -> [Proposal] {
        let response = try await httpClient.execute(
            .init(url: "https://download.swift.org/swift-evolution/proposals.json"),
            deadline: .now() + .seconds(15)
        )
        let buffer = try await response.body.collect(upTo: 1 << 23) /// 8 MB
        let proposals = try decoder.decode([Proposal].self, from: buffer)
        if proposals.isEmpty {
            throw Error.emptyProposals
        }
        return proposals
    }

    func getProposalContent(link: String) async throws -> String {
        let link = link.replacingOccurrences(
            of: "github.com",
            with: "raw.githubusercontent.com"
        )
        let response = try await httpClient.execute(
            .init(url: link),
            deadline: .now() + .seconds(15)
        )
        let buffer = try await response.body.collect(upTo: 1 << 25) /// 32 MB
        let proposal = try decoder.decode(String.self, from: buffer)
        return proposal
    }
}
