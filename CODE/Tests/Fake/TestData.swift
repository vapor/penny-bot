import Foundation

enum TestData {
    private static let testData: [String: Any] = {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let path = currentDirectory + "/Tests/Resources/test_data.json"
        let data = fileManager.contents(atPath: path)!
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
