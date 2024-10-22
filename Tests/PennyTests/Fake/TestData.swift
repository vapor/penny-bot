#if canImport(FoundationEssentials)
import FoundationEssentials
import class Foundation.JSONSerialization
#else
import Foundation
#endif
import DiscordModels
import EvolutionMetadataModel
import GitHubAPI
@testable import Penny

enum TestData {

    private static let decoder = JSONDecoder()

    private static func resource(named name: String) -> Data {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let path = currentDirectory + "/Tests/Resources/" + name
        guard let data = fileManager.contents(atPath: path) else {
            fatalError("Make sure you've set the custom working directory for the current scheme: https://docs.vapor.codes/getting-started/xcode/#custom-working-directory. Current working directory: \(currentDirectory)")
        }
        return data
    }

    private static func resource<D: Decodable>(named name: String, as: D.Type = D.self) -> D {
        let data = resource(named: name)
        return try! JSONDecoder().decode(D.self, from: data)
    }

    static let vaporGuild = resource(
        named: "guild_create.json",
        as: Gateway.GuildCreate.self
    )
    static let proposals = TestData.resource(
        named: "proposals.json",
        as: [Proposal].self
    )
    static let proposalsUpdated = TestData.resource(
        named: "proposals_updated.json",
        as: [Proposal].self
    )
    static let proposalContent = String(
        decoding: TestData.resource(named: "proposal_content.md"),
        as: UTF8.self
    )
    static let soQuestions = TestData.resource(
        named: "soQuestions.json",
        as: SOQuestions.self
    ).items
    static let swiftReleases = TestData.resource(
        named: "swiftReleases.json",
        as: [SwiftOrgRelease].self
    )
    static let swiftReleasesUpdated = TestData.resource(
        named: "swiftReleases_updated.json",
        as: [SwiftOrgRelease].self
    )
    static let newProposalsSample = TestData.resource(named: "new_proposals_sample.json")

    private static let gatewayEvents: [String: Data] = {
        let data = resource(named: "gatewayEvents.json")
        let object = try! JSONSerialization.jsonObject(with: data, options: [])
        let dict = object as! [String: Any]
        let dataDict = dict.mapValues { try! JSONSerialization.data(withJSONObject: $0) }
        return dataDict
    }()

    static func `for`(gatewayEventKey key: String) -> Data? {
        return gatewayEvents[key]
    }

    static func decodedFor(gatewayEventKey key: String) -> Gateway.Event {
        let data = gatewayEvents[key]!
        let decoded = try! decoder.decode(Gateway.Event.self, from: data)
        return decoded
    }

    private static let ghHooksEvents: [String: Data] = {
        let data = resource(named: "ghHooksEvents.json")
        let object = try! JSONSerialization.jsonObject(with: data, options: [])
        let dict = object as! [String: Any]
        let dataDict = dict.mapValues { try! JSONSerialization.data(withJSONObject: $0) }
        return dataDict
    }()

    static func `for`(ghEventKey key: String) -> Data? {
        return ghHooksEvents[key]
    }

    private static let ghRestOperations: [String: Data] = {
        let data = resource(named: "ghRestOperations.json")
        let object = try! JSONSerialization.jsonObject(with: data, options: [])
        let dict = object as! [String: Any]
        let dataDict = dict.mapValues { try! JSONSerialization.data(withJSONObject: $0) }
        return dataDict
    }()

    static func `for`(ghRequestID key: String) -> Data? {
        return ghRestOperations[key]
    }
}
