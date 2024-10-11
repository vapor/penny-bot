#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AsyncHTTPClient
import Models
import EvolutionMetadataModel
import NIOCore

struct DefaultEvolutionService: EvolutionService {
    
    enum Errors: Error, CustomStringConvertible {
        case emptyProposals

        var description: String {
            switch self {
            case .emptyProposals:
                return "emptyProposals"
            }
        }
    }

    let httpClient: HTTPClient
    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func list() async throws -> [Proposal] {
        let response = try await httpClient.execute(
            .init(url: "https://download.swift.org/swift-evolution/v1/evolution.json"),
            deadline: .now() + .seconds(15)
        )
        let buffer = try await response.body.collect(upTo: 1 << 25) /// 32 MiB
        let evolution = try decoder.decode(EvolutionMetadata.self, from: buffer)
        if evolution.proposals.isEmpty {
            throw Errors.emptyProposals
        }
        return evolution.proposals
    }

    func getProposalContent(link: String) async throws -> String {
        /// Converts a link like
        /// https://github.com/apple/swift-evolution/blob/main/proposals/0401-remove-property-wrapper-isolation.md
        /// to
        /// https://raw.githubusercontent.com/apple/swift-evolution/main/proposals/0401-remove-property-wrapper-isolation.md
        /// to get the raw content of the file instead of the GitHub web page.
        let link = link
            .replacing("github.com", with: "raw.githubusercontent.com")
            .replacing("/blob/", with: "/")
        let response = try await httpClient.execute(
            .init(url: link),
            deadline: .now() + .seconds(15)
        )
        let buffer = try await response.body.collect(upTo: 1 << 25) /// 32 MiB
        let content = String(buffer: buffer)
        return content
    }
}
