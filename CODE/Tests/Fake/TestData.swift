import Foundation
import DiscordModels
import PennyModels

public enum TestData {
    
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
    
    public static let vaporGuild = resource(
        named: "guild_create.json",
        as: Gateway.GuildCreate.self
    )
    public static let proposals = TestData.resource(
        named: "proposals.json",
        as: [Proposal].self
    )
    public static let proposalsUpdated = TestData.resource(
        named: "proposals_updated.json",
        as: [Proposal].self
    )
    
    private static let testData: [String: Any] = {
        let data = resource(named: "test_data.json")
        let object = try! JSONSerialization.jsonObject(with: data, options: [])
        return object as! [String: Any]
    }()
    
    /// Probably could be more efficient than encoding then decoding again?!
    static func `for`(key: String) -> Data? {
        if let object = testData[key] {
            return try! JSONSerialization.data(withJSONObject: object)
        } else {
            return nil
        }
    }
}
