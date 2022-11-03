import Foundation

enum TestData {
    private static let testData: [String: Any] = {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let path = currentDirectory + "/Tests/Resources/test_data.json"
        guard let data = fileManager.contents(atPath: path) else {
            fatalError("Make sure you've set the custom working directory for the current scheme: https://docs.vapor.codes/getting-started/xcode/#custom-working-directory")
        }
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
