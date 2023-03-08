import Foundation
import DiscordModels

public enum TestData {
    
    private static func resource(name: String) -> Data {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let path = currentDirectory + "/Tests/Resources/" + name
        guard let data = fileManager.contents(atPath: path) else {
            fatalError("Make sure you've set the custom working directory for the current scheme: https://docs.vapor.codes/getting-started/xcode/#custom-working-directory")
        }
        return data
    }
    
    public static let vaporGuild: Gateway.GuildCreate = {
        let data = resource(name: "guild_create.json")
        return try! JSONDecoder().decode(Gateway.GuildCreate.self, from: data)
    }()
    
    private static let testData: [String: Any] = {
        let data = resource(name: "test_data.json")
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
